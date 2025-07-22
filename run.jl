using Distributed

# This barrier channel is needed for distributed processing to make sure that
# worker processes do not run away from root.
barrier_channel = RemoteChannel(() -> Channel{RemoteChannel}(1))

@everywhere include("main.jl")
#@everywhere main($barrier_channel)