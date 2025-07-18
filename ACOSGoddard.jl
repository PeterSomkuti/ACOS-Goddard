module ACOSGoddard

    include("run.jl")

    function julia_main()::Cint

        main()
        return 0

    end

end