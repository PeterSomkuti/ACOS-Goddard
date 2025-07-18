# Important

Things one must know when doing retrievals from OCO-2/3 measurements, which are not necessarily mentioned in the OCO L2 or L1 algorithm theoretical basis documents. Further, there are a few differences between the operational ACOS retrieval and the ACOS Goddard algorithm.


## Spectral EOFs

Right now, the fitting of empirical orthogonal functions (EOFs) derived from spectral residuals, is not implemented. To our knowledge, this might have minor impact on convergence, but is not known to cause strong biases in the results otherwise. As a consequence, the spectral residuals are higher in magnitude, since for example the systematic errors associated with spectroscopy are still present in the modeled spectra. In general, the reduced $\chi^2$ statistic will be higher with our implementation when compared to the published ACOS results.

## Band-dependent spectroscopy scale factors and their tuning

The pre-calculated spectroscopy tables, known as ABSCO, can be found [here](https://disc.gsfc.nasa.gov/information/glossary?title=OCO-2%20ABSCO). As noted in the documentation therein, the absorption cross section data may or may not be scaled by different factors, depending on the gas and the spectral band. The documentation also provides suggested scale factors for use **in addition to the scale factors that are already applied to the data**.

Users should be aware that those scale factors (the ones mentioned in the ABSCO documentation) were partially derived using retrievals using the NASA ACOS algorithm, and there is no expectation that these must also be the best choice for ACOS-Goddard. Differences in algorithm details and underlying calculations will likely necessitate different scaling factors to be used to achieve like-for-like results between reference ACOS and ACOS-Goddard.

The scale factors can be modified through command line arguments given to the main script (`run.jl` or `run_mpi.jl`) via `--o2_scale 1.0`, `--co2_scale_weak 0.996` or `--co2_scale_strong 1.001`, for example, which will scale the oxygen spectroscopy data, and the CO$_2$ spectroscopy data for the weak (1.6 µm) and strong (2.06 µm) bands respectively.

### ABSCO scale factor tuning

How should one proceed to derive factors?

## Observation azimuth angle

The OCO-2/3 L1 files contain a field that describes the observation azimuth angle: `/FootprintGeometry/footprint_azimuth` (or the band-averaged `/SoundingGeometry/sounding_solar_azimuth`). The convention there is that both solar and observation azimuth angles are relative to an observer located at the ground footprint. This is not the same convention that most radiative transfer codes require (including XRTM). In fact, there is a 180 degree difference between the two conventions. Thus, the observation zenith angle is modified upon read-in by **adding 180 degrees** to the value stored in the L1 files. Therefore, if users compare the `viewing_azimuth` property of a `SatelliteObserver` object, they will note this discrepancy relative to the values from the L1 files.

Further, just before the viewing azimuth angle is fed into XRTM, another check is made to see if the relative angle, meaning the difference between viewing and solar azimuth angles, is within 0 and 360 degrees. The viewing azimuth angle is adjusted accordingly - however that is only a temporary calculation, this change is not reflected in the `viewing_azimuth` property. Thus, inspecting the `/RetrievalGeometry/retrieval_azimuth` of the output file could yield values larger than 360 degrees, and those numbers will also not necessarily be the same as those in comparable ACOS OCO-2/3 L2 files.

The following in-line documentation is found in [RtRetrievalFramework/lib/Interface/level_1b.cc](https://github.com/nasa/RtRetrievalFramework/blob/master/lib/Interface/level_1b.cc) (but omitted in the L1 and L2 ATBDs):

> Azimuth is modified because the convention used by the OCO L1B file is to take both solar and observation angles as viewed from an observer standing in the FOV.  In this convention, the convention or glint would be a relative azimuth difference of 180 degrees, as the spacecraft and sun would be on opposite sides of the sky. However, the radiative transfer convention is that the azimuth angles must be the same for glint (it is "follow the photons" convention). However, we'd like the solar azimuth to not be changed, so as to continue to agree with zenaz, so this change of the observation azimuth has the effect of putting everything in a "reverse follow-the-photons" convention, where we look from the satellite to the FOV, then from the FOV to the sun.  Note that because of an old historical reason, however, both zenith angles remain > 0 and < 90, even in the RT convention.

## L1B bad samples are removed with ACOS

L1B files contain fields `/InstrumentHeader/bad_sample_list`, which allows users to flag spectral samples that should be excluded from spectral fits in retrievals. Values that are non-zero are ignored in the reference ACOS algorithm by excluding them in the spectral fit. Those spectral samples do not appear at all in the various diagnostic files, such as the `L2Dia` family.

In ACOS-Goddard, we chose to include those spectral samples, however we inflate the associated noise-equivalent radiance to such a high amount that those spectral samples have no impact on the spectral fit. When comparing spectral fits between reference ACOS and ACOS-Goddard, users might see missing points that can be attributed to this difference in how bad samples are treated.

## Scaled Levenberg-Marquardt iteration

The OCO-2/3 L2 ATBD explains the used inverse formulation in the section *Inverse Method*, *Formulation and Implementation*. As mentioned there, we shall look at equation (5.36) in Rodgers (2000), which explicitly writes the state vector update at iteration ``i`` as (consult Rodgers (2000) and the OCO ATBDs for the meaning of the variables):

```math
\mathbf{x}_{i+1} = \mathbf{x}_i + \lbrack (1 + \gamma) \mathbf{S}_\mathrm{a}^{-1} + \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \mathbf{K}_i \rbrack^{-1} \\
\times \lbrace \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \lbrack \mathbf{y} - \mathbf{F}(\mathbf{x}_i)\rbrack - \mathbf{S}_\mathrm{a}^{-1} \lbrack \mathbf{x}_i - \mathbf{x}_\mathrm{a}\rbrack \rbrace.
```

The OCO-2/3 L2 ATBD then mentions that the state vector update is not calculated in that manner, but rather in the following way. First, we make a substitution and write the state vector update like so: ``\mathrm{d}\mathbf{x}_i = \mathbf{x}_{i+1} - \mathbf{x}_i``. Then we re-arrange the first in the brackets to obtain the following:

```math
\lbrack (1 + \gamma) \mathbf{S}_\mathrm{a}^{-1} + \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \mathbf{K}_i \rbrack \mathrm{d}\mathbf{x}_i = \lbrace \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \lbrack \mathbf{y} - \mathbf{F}(\mathbf{x}_i)\rbrack - \mathbf{S}_\mathrm{a}^{-1} \lbrack \mathbf{x}_i - \mathbf{x}_\mathrm{a}\rbrack \rbrace.
```

This is algebraically equivalent with the formulation above that is also found in Rodgers (2000), however the substantial difference is that the matrix inverse is no longer explicitly needed. As the OCO-2/3 L2 ATBD further elaborates, one can solve this problem with a variety of easily obtainable solvers, such as a least-squares solver. The left-hand side operator (``(1 + \gamma) \mathbf{S}_\mathrm{a}^{-1} + \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \mathbf{K}_i``) is a matrix-valued quantity, whereas the right-hand side (``\mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \lbrack \mathbf{y} - \mathbf{F}(\mathbf{x}_i)\rbrack - \mathbf{S}_\mathrm{a}^{-1} \lbrack \mathbf{x}_i - \mathbf{x}_\mathrm{a}\rbrack``) is a vector. Hence the problem reduces to a simple ``\mathbf{A}\cdot\mathrm{d}\mathbf{x}_i = \mathbf{b}`` type problem.

The reference ACOS algorithm, however, actually applies a scaling to this equation, which is not mentioned in the ATBD. It is explained in [lib/Implementation/connor_solver.cc](https://github.com/nasa/RtRetrievalFramework/blob/master/lib/Implementation/connor_solver.cc), that both sides of the equation are first scaled by some matrix, which we will call ``\mathbf{N}`` here.

First, we can re-write the above equation to yield:

```math
\mathbf{N}^\mathrm{T} \lbrack (1 + \gamma) \mathbf{S}_\mathrm{a}^{-1} + \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \mathbf{K}_i \rbrack \mathbf{N} \mathbf{N}^{-1} \mathrm{d}\mathbf{x}_i = \mathbf{N}^\mathrm{T} \lbrace \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \lbrack \mathbf{y} - \mathbf{F}(\mathbf{x}_i)\rbrack - \mathbf{S}_\mathrm{a}^{-1} \lbrack \mathbf{x}_i - \mathbf{x}_\mathrm{a}\rbrack \rbrace.
```

Note that ``\mathbf{N} \mathbf{N}^{-1}`` has been wedged in front of ``\mathrm{d}\mathbf{x}_i``. In the above quoted reference ACOS code, ``\mathbf{N}`` was chosen to be a diagonal matrix, consisting of the diagonal entries of the prior covariance matrix: ``\mathbf{N} = \mathrm{diag}(\mathbf{S}_\mathrm{a})``.

The problem can now be formulated as

```math
\mathbf{A} = \mathbf{N}^\mathrm{T} \lbrack (1 + \gamma) \mathbf{S}_\mathrm{a}^{-1} + \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \mathbf{K}_i \rbrack \\
\mathbf{b} = \mathbf{N}^\mathrm{T} \lbrace \mathbf{K}_i^\mathrm{T} \mathbf{S}_\varepsilon^{-1} \lbrack \mathbf{y} - \mathbf{F}(\mathbf{x}_i)\rbrack - \mathbf{S}_\mathrm{a}^{-1} \lbrack \mathbf{x}_i - \mathbf{x}_\mathrm{a}\rbrack \rbrace
```

and we attempt to solve ``\mathbf{A} \cdot \mathbf{x} = \mathbf{b}``.

Again, there is a difference between the OCO-2/3 ATBD and what is actually implemented in the reference ACOS. Rather than using some generic least-square solver to solve ``\mathbf{A} \cdot \mathbf{x} = \mathbf{b}``, they solve the problem via singular value decomposition. Doing so, the left-hand side is decomposed:

```math
\mathbf{A} = \mathbf{U}\mathbf{S}\mathbf{V}^\mathrm{T},
```

where ``\mathbf{S}`` is a diagonal matrix. In the case of reference ACOS, any diagonal entry ``s_m`` that is below some threshold ``<10^{-12}``  is set to zero. With the modified entries to ``\mathbf{S}``, we can write the inverse as ``\mathbf{S}^{-1} = \mathrm{diag}(s_1, s_2, s_3, \ldots, 0)`` (where any ``s_m < 10^{-12} = 0``) and the solution to the problem is

```math
\mathbf{x} = \mathbf{V} \mathbf{S}^{-1} \mathbf{U}^\mathrm{T}\mathbf{b}
```

and then finally

```math
\mathrm{d}\mathbf{x}_i = \mathbf{N} \mathbf{x}.
```

Thus the new state vector becomes

```math
\mathbf{x}_{i+1} = \mathbf{x}_i + \mathrm{d}\mathbf{x}_i.
```

ACOS-Goddard implements this scheme via the function `solve_LM_scaled` that is provided within RetrievalToolbox.


## Phase function expansion coefficient convention

The reference implementation, RtRetrievalFramework, uses the LIDORT family of radiative transfer solvers. Those models and codes use the so-called *de Rooij* convention for the phase function expansion coefficients. We make use of [XRTM](https://github.com/gmcgarragh/xrtm), which uses the *Siewert* convention.

In the de Rooij convention, the six needed expansion coefficients for the phase matrix are called $\alpha_1^l$, $\alpha_2^l$, $\alpha_3^l$, $\alpha_4^l$, $\beta_1^l$ and $\beta_2^l$, whereas the *Siewert* convention calls them $\alpha_l$, $\beta_l$, $\zeta_l$, $\delta_l$, $\gamma_l$ and $\epsilon_l$. Further, XRTM does not ingest the six moments as such, but requires $-\gamma_l$ and $-\epsilon_l$.

In this application, and such is done also in the helper function that ships with RetrievalToolbox, we reorder the coefficients to match the *Siewert* convention, and also **change the sign** of both $\gamma_l$ and $\epsilon_l$ such that no further modification to the coefficients is needed. However, this also means that the `MieMomAerosolProperty` objects really store  $\alpha_l$, $\beta_l$, $\zeta_l$, $\delta_l$, $-\gamma_l$ and $-\epsilon_l$.