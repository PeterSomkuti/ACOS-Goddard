using Distributed

# This barrier channel is needed for distributed processing to make sure that
# worker processes do not run away from root.
barrier_channel = RemoteChannel(() -> Channel{RemoteChannel}(1))
sync_channel = RemoteChannel(() -> Channel{Any}(nworkers() * 2))

# We have to make sure all workers have the same command line arguments before
# we enter main.jl

@everywhere include("main.jl")
@everywhere main($barrier_channel, $sync_channel, $ARGS)