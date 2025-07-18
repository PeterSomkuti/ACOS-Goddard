# Needed to convert results into ACOS-compliant retrieval results
include("collect_results_RetrievalResults.jl")

"""
$(TYPEDSIGNATURES)

Creates a dictionary String => Any that contains the results of a retrieval, packaged up
like the single-retrieval ACOS L2 file.

# Details

Every single-value result data (e.g. SZA or surface pressure) is contained in a 1-D vector
with a single entry. Any multi-valued result (e.g. CO2 profile or averaging kernel) has to
be re-arranged into a 2D array, with the last dimension having one entry. So a CO2
profile with 20 entries must be of shape [20,1]; the AK matrix must be [20, 20, 1]. Note
that upon writing out into HDF5, the dimension order gets reversed. So the Jacobian matrix,
which in RetrievalToolbox has shape [Nobs, Nsv] must be arranged to be [Nsv, Nobs, 1], so
that in "C-order" in the final file it becomes [1, Nobs, Nsv] when read with e.g. h5ls.

"""
function collect_results(
        s::RE.AbstractSolver,
        buf::RE.EarthAtmosphereBuffer,
)

    # Calculate OE stuff
    q = RE.calculate_OE_quantities(s)

    if isnothing(q)
        return nothing
    end

    h = RE.create_pressure_weights(buf.scene.atmosphere)
    # Store Jacobian
    K = RE.create_K_from_solver(s);
    # Prior covariance matrix
    Sa = s.prior_covariance
    # Measurement covariance matrix
    Se = RE.create_Se_from_solver(s);

    # Result dictionary
    result = Dict{String, Any}()

    # Retrieval geometry
    result["/RetrievalGeometry/retrieval_azimuth"] = [buf.scene.observer.viewing_azimuth]
    result["/RetrievalGeometry/retrieval_zenith"] = [buf.scene.observer.viewing_zenith]
    result["/RetrievalGeometry/retrieval_solar_azimuth"] = [buf.scene.solar_azimuth]
    result["/RetrievalGeometry/retrieval_solar_zenith"] = [buf.scene.solar_zenith]

    # State vector results
    sv = s.state_vector
    result["/RetrievedStateVector/state_vector_names"] = permutedims(cat(RE.get_name(sv)..., dims=2), (2,1))
    result["/RetrievedStateVector/state_vector_apriori"] = cat(RE.get_prior_value(sv)..., dims=2)'
    result["/RetrievedStateVector/state_vector_apriori_uncert"] = cat(RE.get_prior_uncertainty(sv)..., dims=2)'
    result["/RetrievedStateVector/state_vector_result"] = cat(RE.get_current_value(sv)..., dims=2)'
    result["/RetrievedStateVector/state_vector_initial"] = cat(RE.get_first_guess(sv)..., dims=2)'
    result["/RetrievedStateVector/state_vector_aposteriori_uncert"] = cat(q.SV_ucert..., dims=2)'

    # Measured and modelled, along with measurement noise
    # (as big arrays)
    measured = RE.get_measured(s)
    modeled = RE.get_modeled(s)
    noise = RE.get_noise(s)

    result["/SpectralParameters/modeled_radiance"] = cat(modeled..., dims=2)'
    result["/SpectralParameters/measured_radiance"] = cat(measured..., dims=2)'
    result["/SpectralParameters/measured_radiance_uncert"] = cat(noise..., dims=2)'

    # Calculate residual RMS
    for swin in keys(s.indices)
        meas = RE.get_measured(s, swin, view=false)
        conv = RE.get_modelled(s, swin, view=false)

        rms = sqrt(mean((conv .- meas).^2))
        result["/SpectralParameters/residual_mean_square_$(swin.window_name)"] = [rms]
    end

    # Calculate chi2
    chi2_all = RE.calculate_chi2(s)
    for (swin, chi2) in chi2_all
        result["/SpectralParameters/reduced_chi_squared_$(swin.window_name)"] = [chi2]
    end

    result["/RetrievalResults/jacobian"] = permutedims(K[[CartesianIndex()], :, :], (3,2,1))

    # High-resolution radiances and Jacobians
    #=
    for (swin, rt) in buf.rt
        result["/HighResSpectra/radiance_$(swin.window_name)"] = rt.hires_radiance.S[:,:]
        for (idx, sve) in enumerate(s.state_vector.state_vector_elements)
            result["/HighResSpectra/jacobian_$(swin.window_name)_$(idx)"] = rt.hires_jacobians[sve].S[:,:]
        end
    end
    =#


    # #################################################
    # Pack all available results into /RetrievalResults
    # #################################################

    # Meteorology / atmospheric state
    atm = buf.scene.atmosphere

    result["/RetrievalResults/vector_pressure_levels"] =
        cat((atm.pressure_levels * atm.pressure_unit .|> u"Pa" .|> ustrip)..., dims=2)'
    result["/RetrievalResults/vector_pressure_levels_met"] =
        cat((atm.met_pressure_levels * atm.met_pressure_unit .|> u"Pa" .|> ustrip)..., dims=2)'
    result["/RetrievalResults/specific_humidity_profile_met"] =
        cat((atm.specific_humidity_levels * atm.specific_humidity_unit .|> NoUnits .|> ustrip)..., dims=2)'
    result["/RetrievalResults/temperature_profile_met"] =
        cat((atm.temperature_levels * atm.temperature_unit .|> u"K" .|> ustrip)..., dims=2)'


    # total column for each gas
    for gas in atm.atm_elements
        !(gas isa RE.GasAbsorber) && continue

        # Nair_dry is the same for all windows
        nair_dry = first(values(buf.optical_properties)).nair_dry
        result["/RetrievalResults/retrived_dry_air_column_layer"] =
            cat(nair_dry..., dims=2)'
        # Nair_wet
        nair_wet = first(values(buf.optical_properties)).nair_wet
        result["/RetrievalResults/retrived_wet_air_column_layer"] =
            cat(nair_wet..., dims=2)'

        gas_layer = RE.levels_to_layers(gas.vmr_levels * gas.vmr_unit .|> NoUnits)
        gname = lowercase(gas.gas_name)
        result["/RetrievalResults/retrieved_$(gname)_column"] =
            [gas_layer .* nair_dry |> sum]

    end


    # Do all state vector elements with custom functions
    for sve in sv.state_vector_elements
        ACOS_RetrievalResult!(result, sve, q)
    end

    # Iterations
    # Grab all iterations from each state vector element:
    un_it = unique((x -> length(x.iterations)).(s.state_vector.state_vector_elements))
    if length(un_it) == 1
        result["/RetrievalResults/iterations"] = [un_it[1]]
    else
        @error "Problem! State vector elements do not all have the same # of iterations!"
    end

    # Pressure weights
    result["/RetrievalResults/xco2_pressure_weighting_function"] = cat(h..., dims=2)'

    # DOF for full state vector
    result["/RetrievalResults/dof_full_vector"] = [diag(q.AK) |> sum]

    # Prior covariance
    result["/RetrievalResults/apriori_covariance_matrix"] =
        permutedims(Sa[[CartesianIndex()], :, :], (3,2,1))

    # Take the CO2 profile
    gas_co2 = RE.get_gas_from_name(buf.scene.atmosphere, "CO2")

    # If it is present, grab the CO2 profile from the state vector!
    if !isnothing(gas_co2)

        co2_idx = RE.idx_for_profile_sve(gas_co2, sv)

        if length(co2_idx) > 1
            unit_fac = 1.0 * gas_co2.vmr_unit |> NoUnits

            co2_profile = RE.get_current_value_with_unit(sv)[co2_idx] .|> NoUnits
            co2_profile_ap = RE.get_prior_value_with_unit(sv)[co2_idx] .|> NoUnits

            co2_profile_uncert = q.SV_ucert[co2_idx] * unit_fac
            co2_profile_cov = q.Shat[co2_idx, co2_idx] .* (unit_fac)^2

            result["/RetrievalResults/co2_profile"] =
                cat(co2_profile..., dims=2)'
            result["/RetrievalResults/co2_profile_apriori"] =
                cat(co2_profile_ap..., dims=2)'
            result["/RetrievalResults/co2_profile_uncert"] =
                cat(co2_profile_uncert..., dims=2)'
            result["/RetrievalResults/co2_profile_covariance_matrix"] =
                permutedims(co2_profile_cov[[CartesianIndex()], :, :], (3,2,1))
            result["/RetrievalResults/dof_co2_profile"] = [diag(q.AK)[co2_idx] |> sum]

            # Calculate the mystical CO2 grad del
            co2_grad_del = (co2_profile[20] - co2_profile[12]) -
                (co2_profile_ap[20] - co2_profile_ap[12]) # these are in unit 1
            result["/RetrievalResults/co2_vertical_gradient_delta"] = [co2_grad_del]

        end
    end

    # Take all XGases
    xgas = RE.calculate_xgas(buf.scene.atmosphere)
    # CO2 specific results (if present)
    if "CO2" in keys(xgas)

        co2_idx = RE.idx_for_profile_sve(gas_co2, sv)
        # non-CO2 indices
        nonco2_idx = setdiff(collect(1:length(sv)), co2_idx)
        # Store XCO2
        result["/RetrievalResults/xco2"] = [xgas["CO2"] |> NoUnits]

        # TODO
        # Prior XCO2 is tricky! The atmospheric state (surface pressure!) has changed
        # from before the retrieval, hence we cannot trivially produce the initial (prior)
        # XCO2. For now, we set this to NaN. Easiest solution would be to calculate this
        # value at the start of the retrieval, and keep it stored somewhere..
        result["/RetrievalResults/xco2_apriori"] = [NaN]


        # XCO2 uncertainty
        xco2_uncert = sqrt(dot(h' * q.Shat[co2_idx, co2_idx], h)) # in "native" units
        xco2_uncert *= unit_fac
        result["/RetrievalResults/xco2_uncert"] = [xco2_uncert]

        # Calculate smoothing, interference and noise contributions to uncertainty
        # See OCO L2 ATBD sections 3.6.3 and following

        # Measurement error posterior covariance (we take the CO2-only portion out)
        Shat_meas = (q.G * Se * q.G')[co2_idx, co2_idx]
        # AK part that involves CO2
        NCO2 = length(co2_idx)
        I = Diagonal(ones(NCO2))
        AKCO2 = q.AK[co2_idx, co2_idx]
        # Smoothing error due to CO2
        Shat_smooth = (AKCO2 - I) * q.Sa[co2_idx, co2_idx] * (AKCO2 - I)'

        # AKue -> CO2 rows, non-CO2 columns
        AKue = q.AK[co2_idx, nonco2_idx]
        # Sae -> prior covariance with non-CO2 for both
        Sae = q.Sa[nonco2_idx, nonco2_idx]
        Shat_interference = AKue * Sae * AKue'

        # Now produce the XCO2 uncerts for all components
        xco2_u_m = sqrt(dot(h' * Shat_meas, h)) * unit_fac
        xco2_u_sm = sqrt(dot(h' * Shat_smooth, h)) * unit_fac
        xco2_u_if = sqrt(dot(h' * Shat_interference, h)) * unit_fac

        # Check if math was correct..
        if !(xco2_uncert ≈ sqrt(xco2_u_m^2 + xco2_u_sm^2 + xco2_u_if^2))
            @warn "XCO2 uncertainty calculation might be wrong! " *
            "error components do not add up."
        end

        result["/RetrievalResults/xco2_uncert_interf"] = [xco2_u_if]
        result["/RetrievalResults/xco2_uncert_noise"] = [xco2_u_m]
        result["/RetrievalResults/xco2_uncert_smooth"] = [xco2_u_sm]

    end

    # Normed AK
    # Do this only if we have CO2 in the atmosphere, and are also retrieving it!
    if ("CO2" in keys(xgas)) & !isnothing(q)
        ind = RE.idx_for_profile_sve(gas_co2, s.state_vector)
        if length(ind) > 0
            AKCO2 = q.AK[ind,ind];

            ak = (h' * AKCO2)'
            ak_norm = ak ./ h

            result["/RetrievalResults/xco2_avg_kernel"] = cat(ak..., dims=2)'
            result["/RetrievalResults/xco2_avg_kernel_norm"] = cat(ak_norm..., dims=2)'
        end
    end

    return result

end