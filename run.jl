using Distributed

# This barrier channel is needed for distributed processing to make sure that
# worker processes do not run away from root.
barrier_channel = RemoteChannel(() -> Channel{RemoteChannel}(1))
sync_channel = RemoteChannel(() -> Channel{Any}(nworkers() * 2))


# Check to see if XRTM_PATH is set.
if !haskey(ENV, "XRTM_PATH")
    @error "This application needs the XRTM radiative transfer library!"
    error("Environment variable XRTM_PATH must be set!")
end


# We have to make sure all workers have the same command line arguments before
# we enter main.jl

@everywhere include("main.jl")
@everywhere main($barrier_channel, $sync_channel, $ARGS)