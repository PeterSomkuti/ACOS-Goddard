function parse_commandline(ARGS_input)

    s = ArgParseSettings()
    @add_arg_table! s begin

        "--logfile"
            help = "Path to log file"
            arg_type = String
            required = false
        "--solar_model"
            help = "Path to solar model file"
            arg_type = String
            required = true
        "--L1b"
            help = "Path to L1b file"
            arg_type = String
            required = true
        "--L2Met"
            help = "Path to L2Met file"
            arg_type = String
            required = true
        "--L2CPr"
            help = "Path to L2CPr file"
            arg_type = String
            required = true
        "--sounding_id"
            help = "Sounding IDs (16-digit integer)"
            arg_type = Int
            nargs = '*'
            required = false
        "--sounding_id_list"
            help = "Path to Sounding ID list"
            arg_type = String
            required = false
        "--spec"
            help = "Which spectrometers? Separated by comma: e.g. 1,2 or 1, or 1,2,3 (O2, weak CO2, strong CO2)"
            arg_type = String
            required = true
        "--output"
            help = "Output file name"
            arg_type = String
            required = true
        "--Lambertian"
            help = "Use a Lambertian surface model, and not the RPV BRDF (default = false)"
            arg_type = Bool
            required = false
            default = false
        "--aerosols"
            help = "Whether to use aerosols or not (default = true)"
            arg_type = Bool
            required = false
            default = true
        "--retrieve_aerosols"
            help = "Whether to retrieve aerosols or not (default = true)"
            arg_type = Bool
            required = false
            default = true
        "--retrieve_psurf"
            help = "Whether to retrieve surface pressure or not (default = true)"
            arg_type = Bool
            required = false
            default = true
        "--polarized"
            help = "Whether to use polarized RT or not (default = true)"
            arg_type = Bool
            required = false
            default = true
        "--LSI"
            help = "Whether to use LSI or not (default = true)"
            arg_type = Bool
            required = false
            default = true
        "--Nhigh"
            help = "Number of high-accuracy quadrature streams for RT (default = 16)"
            arg_type = Int
            required = false
            default = 16
        "--max_iterations"
            help = "Number of allowed iterations before the inversions are halted (default = 10)."
            arg_type = Int
            required = false
            default = 10
        "--gamma"
            help = "Levenberg-Marquardt gamma value (default = 10)."
            arg_type = Float64
            required = false
            default = 10.0
        "--dsigma_scale"
            help = "Scale factor to (dσ)^2 to assess convergence"
            arg_type = Float64
            required = false
            default = 2.0
        "--o2_spec"
            help = "Path to O2 spectroscopy"
            arg_type = String
            required=true
        "--o2_scale"
            help = "Oxygen spectroscopy scaling factor"
            arg_type = Float64
            required = false
            default = 1.0
        "--co2_spec"
            help = "Path to CO2 spectroscopy"
            arg_type = String
            required=true
        "--co2_scale_weak"
            help = "CO2 spectroscopy scale factor for the weak CO2 band"
            arg_type = Float64
            required = false
            default = 1.0
        "--co2_scale_strong"
            help = "CO2 spectroscopy scale factor for the strong CO2 band"
            arg_type = Float64
            required = false
            default = 1.0
        "--h2o_spec"
            help = "Path to H2O spectroscopy"
            arg_type = String
            required=true
    end

    return parse_args(ARGS_input, s)

end