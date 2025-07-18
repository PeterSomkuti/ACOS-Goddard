# Known Issues

This page lists the currently known issues with this ACOS implementation - these are items that could be changed or fixed in the future. Users should be aware of them when making comparisons to results from ACOS retrievals.

## Memory use due to Low-Streams Interpolation (LSI)

The current version uses a large amount of memory when the retrieval is run with low-streams interpolation to include high-accuracy multiple scattering, including polarization. Peak memory usage is ~7GB when one process is used. This is a result of how the additional instances of the radiative transfer objects are spawned.

The ACOS algorithm as used with OCO-2/3 measurements requires a total of 4 different RT solver modes: a vector single-scattering one, a scalar two-stream one, a vector two orders of scattering (2OS) one, and a scalar discrete ordinate one for an arbitrary number of streams. During the "binned" calculations in which we perform the RT for representative profiles, these four solver modes have to be spawned for every bin. This produces significant overhead in terms of memory. For now, we have chosen to keep the current solution as to not sacrifice legibility for a lower memory footprint. Future versions of RetrievalToolbox or ACOS-Goddard might change this.

For benchmarking purposes, the memory footprint can be lowered by omitting LSI (`--LSI false`), disabling polarization (`--polarized false`) or disabling aerosols (`--aerosols false` or `--retrieve_aerosols false`).

## Non-linearity and divergent steps

At the moment we find that the retrieval behaves more non-linearly when the modeled and measured radiances are very close to each other. So when getting closer to convergence, the retrieval is more likely to produce a divergent step - meaning that the linear prediction for a given state vector update is wrong and the cost function actually increases as a result of that update. We suspect that some of the Jacobian calculations have small errors in them that become more apparent once the retrieval closes in on a state vector that is close to being converged. As a temporary fix, we add a little code snippet that bumps up the Levenberg-Marquard γ parameter when the retrieval gets closer to convergence:

``` julia
    chi2 = RE.calculate_chi2(solver)
    all_chi2_small = true
    for (k,v) in chi2
        @info "$(k): χ² = $(v)"
        if (v > 20)
            all_chi2_small = false
        end
    end

    # Manually push gamma to 1000 when we get closer to the solution for better
    # convergence
    if (all_chi2_small)
        solver.gamma = 1000
        @info "Setting LM-γ to $(solver.gamma)"
    end
```

So whenever the retrieval gets to a point where the χ^2 is less than some value (here 20), the γ parameter is bumped up to 1000 to make the state vector update steps smaller, which hopefully keeps the updates in the more linear regime.

## FootprintGeometry not used

## No consideration for off-pointing between spectrometers

Both OCO-2 and OCO-3 instruments have slight off-pointing between the three spectrometers, meaning that the locations on Earth that each band "sees" is slightly different. While of not much concern regarding smooth geo-physical variables like CO$_2$ concentrations or aerosol abundance, there could be significant impact due to the varying surface pressure (or total oxygen column) in rough terrain. We do not account for this off-pointing between spectrometers yet.

## Surface pressure Jacobian

## BRDF parameters

## No spectral dependence of scattering phase function

At the moment, the computation of the scattering phase function expansion coefficients is only done once per spectral window. This means that the overall scattering properties are calculated only once and then re-used for the entire spectral window. At the moment, this is done for performance reasons - the way the coefficients are calculated inside the spectral loop (inside of `RT_XRTM.jl`) is not optimal and performing the calculation for every spectral point would increase the run-time of retrievals significantly. This will be re-visited. Note, however, that this is an issue related to `RetrievalToolbox`, rather than our ACOS implementation.