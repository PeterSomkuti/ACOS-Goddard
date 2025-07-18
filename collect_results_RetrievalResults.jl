# Default does nothing
ACOS_RetrievalResult!(result::Dict, sve::AbstractStateVectorElement, q::OEQuantities) = nothing

function ACOS_RetrievalResult!(
    result::Dict,
    sve::RE.SurfacePressureSVE,
    q::RE.OEQuantities,
    )

    val = RE.get_current_value_with_unit(sve) |> u"Pa" |> ustrip
    ucert = RE.get_posterior_ucert(q, sve) * sve.unit |> u"Pa" |> ustrip
    apriori = RE.get_prior_value_with_unit(sve) |> u"Pa" |> ustrip

    result["/RetrievalResults/surface_pressure_fph"] = [val]
    result["/RetrievalResults/surface_pressure_uncert_fph"] = [ucert]
    result["/RetrievalResults/surface_pressure_apriori_fph"] = [apriori]

end

function ACOS_RetrievalResult!(
    result::Dict,
    sve::RE.TemperatureOffsetSVE,
    q::RE.OEQuantities,
    )

    val = RE.get_current_value_with_unit(sve) |> u"K" |> ustrip
    ucert = RE.get_posterior_ucert(q, sve) * sve.unit |> u"K" |> ustrip
    apriori = RE.get_prior_value_with_unit(sve) |> u"K" |> ustrip

    result["/RetrievalResults/temperature_offset_fph"] = [val]
    result["/RetrievalResults/temperature_offset_uncert_fph"] = [ucert]
    result["/RetrievalResults/temperature_offset_apriori_fph"] = [apriori]

end

function ACOS_RetrievalResult!(
    result::Dict,
    sve::RE.DispersionPolynomialSVE,
    q::RE.OEQuantities,
    )

    order = sve.coefficient_order
    sname = sve.dispersion.spectral_window.window_name

    if order == 0
        suffix = "offset"
    elseif order == 1
        suffix = "spacing"
    else
        @warn "Do not know name for $(sve) and order $(order)"
    end

    val = RE.get_current_value(sve)
    ucert = RE.get_posterior_ucert(q, sve)
    apriori = RE.get_prior_value(sve)

    result["/RetrievalResults/dispersion_$(suffix)_$(sname)"] = [val]
    result["/RetrievalResults/dispersion_$(suffix)_uncert_$(sname)"] = [ucert]
    result["/RetrievalResults/dispersion_$(suffix)_apriori_$(sname)"] = [apriori]

end

function ACOS_RetrievalResult!(
    result::Dict,
    sve::RE.GasLevelScalingFactorSVE,
    q::RE.OEQuantities,
    )

    gname = lowercase(sve.gas.gas_name)

    val = RE.get_current_value_with_unit(sve) |> NoUnits |> ustrip
    ucert = RE.get_posterior_ucert(q, sve) * sve.unit |> NoUnits |> ustrip
    apriori = RE.get_prior_value_with_unit(sve) |> NoUnits |> ustrip

    result["/RetrievalResults/$(gname)_scale_factor"] = [val]
    result["/RetrievalResults/$(gname)_scale_factor_uncert"] = [ucert]
    result["/RetrievalResults/$(gname)_scale_factor_apriori"] = [apriori]

end


function ACOS_RetrievalResult!(
    result::Dict,
    sve::RE.BRDFPolynomialSVE,
    q::RE.OEQuantities,
    )

    order = sve.coefficient_order

    if order == 0
        suffix = ""
    elseif order == 1
        suffix = "_slope"
    elseif order == 2
        suffix = "_quadratic"
    elseif order == 3
        suffix = "_cubic"
    else
        @warn "Do not know name for $(sve) and order $(order)"
    end

    sname = sve.swin.window_name

    val = RE.get_current_value(sve)
    ucert = RE.get_posterior_ucert(q, sve)
    apriori = RE.get_prior_value(sve)

    result["/RetrievalResults/brdf_weight$(suffix)_$(sname)"] = [val]
    result["/RetrievalResults/brdf_weight$(suffix)_uncert_$(sname)"] = [ucert]
    result["/RetrievalResults/brdf_weight$(suffix)_apriori_$(sname)"] = [apriori]

end
