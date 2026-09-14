# =============================================================================
# 11_run_queue.jl — run a list of cells sequentially in one Julia process
# (so the ~1 min harness load is paid once). Start several of these in
# parallel with disjoint queues to use the machine.
# =============================================================================
#
#   julia --project=. -t 4 scripts/11_run_queue.jl queue_A.txt [--out DIR] [--tmax N] [--nseed N]
#
# Queue file: one cell per line, "alg ordering B seed [exps]", e.g. "mw NO 5e4 11"
# or "mw IO 5e4 11 dayabay,minos". Lines starting with # are ignored.
# --out / --tmax / --nseed apply to every cell of the queue (ablation runs).
include(joinpath(@__DIR__, "10_run_cell.jl"))

function run_queue(path; out = joinpath(@__DIR__, "..", "out"), tmax = nothing, nseed = nothing)
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        f = split(s)
        o = Dict{String,Any}("alg" => Symbol(f[1]), "ordering" => String(f[2]),
            "B" => parse(Float64, f[3]), "seed" => parse(Int, f[4]),
            "exps" => length(f) >= 5 ? String(f[5]) : join(NEUTRINO_DEFAULT_EXPERIMENTS, ","),
            "out" => out, "force" => false, "tmax" => tmax, "nseed" => nseed)
        t0 = time()
        try
            run_cell(o)
        catch err
            @error "cell failed" line = s exception = (err, catch_backtrace())
        end
        println("QUEUE-CELL-DONE ", s, "  ", round(time() - t0; digits = 1), " s")
        GC.gc()
    end
    println("QUEUE-DONE ", path)
end

if abspath(PROGRAM_FILE) == @__FILE__
    io = findfirst(==("--out"), ARGS); it = findfirst(==("--tmax"), ARGS); ins = findfirst(==("--nseed"), ARGS)
    run_queue(ARGS[1]; out = io === nothing ? joinpath(@__DIR__, "..", "out") : ARGS[io+1],
              tmax = it === nothing ? nothing : parse(Int, ARGS[it+1]),
              nseed = ins === nothing ? nothing : parse(Int, ARGS[ins+1]))
end
