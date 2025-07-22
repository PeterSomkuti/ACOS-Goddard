using RetrievalToolbox
const RE = RetrievalToolbox

function main()

    local coord_channel

    if myid() == 1
        println("Creating coordination channel")
        coord_channel = RemoteChannel(() -> Channel{Dict{String, RE.AbstractSpectroscopy}}(1))
    else
        println("Workers pause and wait for root to create the channel..")
        sleep(2.0)
        coord_channel = @fetchfrom 1 Main.coord_channel
        println("Received coordination channel")

    end

    if myid() == 1
        @eval Main coord_channel = $coord_channel
    end

    if myid() == 1
        abscos = Dict{String, RE.AbstractSpectroscopy}()
        abscos["O2"] = RE.load_ABSCO_spectroscopy(
                # Pass the path to the ABSCO file
                "data/o2_v52.hdf",
                spectral_unit=:Wavelength,
                distributed=true
            )

        put!(coord_channel, abscos)
    else

        abscos = take!(coord_channel)
        println("Received ABSCO")
        if myid() < nworkers() + 1
            println("Putting back ABCSO")
            put!(coord_channel, abscos)
        end

    end


end


main()