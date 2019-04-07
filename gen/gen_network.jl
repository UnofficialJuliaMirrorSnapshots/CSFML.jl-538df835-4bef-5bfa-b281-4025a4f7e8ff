using Clang

const SFML_INCLUDE = joinpath(@__DIR__, "..", "deps", "usr", "include")
const GRAPHICS_DIR = joinpath(SFML_INCLUDE, "SFML", "Network")
const GRAPHICS_HEADERS = [joinpath(GRAPHICS_DIR, header) for header in readdir(GRAPHICS_DIR) if endswith(header, ".h")]
const GRAPHICS_H = joinpath(SFML_INCLUDE, "SFML", "Network.h")

# create a work context
ctx = DefaultContext()

# parse headers
parse_headers!(ctx, [GRAPHICS_H, GRAPHICS_HEADERS...], includes=[SFML_INCLUDE, CLANG_INCLUDE])

# settings
ctx.libname = "libcsfml_network"
ctx.options["is_function_strictly_typed"] = false
ctx.options["is_struct_mutable"] = false  # for nested struct

# write output
api_file = joinpath(@__DIR__, "..", "src", "Network", "network_api.jl")
api_stream = open(api_file, "w")

for trans_unit in ctx.trans_units
    root_cursor = getcursor(trans_unit)
    push!(ctx.cursor_stack, root_cursor)
    header = spelling(root_cursor)
    @info "wrapping header: $header ..."
    # loop over all of the child cursors and wrap them, if appropriate.
    ctx.children = children(root_cursor)
    for (i, child) in enumerate(ctx.children)
        child_name = name(child)
        child_header = filename(child)
        ctx.children_index = i
        # choose which cursor to wrap
        startswith(child_name, "__") && continue  # skip compiler definitions
        child_name in keys(ctx.common_buffer) && continue  # already wrapped
        child_header != header && continue

        wrap!(ctx, child)
    end
    @info "writing $(api_file)"
    println(api_stream, "# Julia wrapper for header: $header")
    println(api_stream, "# Automatically generated using Clang.jl\n")
    print_buffer(api_stream, ctx.api_buffer)
    empty!(ctx.api_buffer)  # clean up api_buffer for the next header
end
close(api_stream)

# write "common" definitions: types, typealiases, etc.
common_file = joinpath(@__DIR__, "..", "src", "Network", "network_common.jl")
open(common_file, "w") do f
    println(f, "# Automatically generated using Clang.jl\n")
    print_buffer(f, dump_to_buffer(ctx.common_buffer))
end
