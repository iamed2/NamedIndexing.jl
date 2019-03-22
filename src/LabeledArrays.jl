module LabeledArrays using Random

export LabeledArray
export labels

""" Auto-generated axis name.

In practice, each name is paired with a single axis number. E.g. axis 1 will always have the
same name across a session. However, form one session to the next, the names may change.
"""
const AUTO_AXIS_NAMES = let
    names = ("lapin", "rat", "corbeau", "cochon", "saumon", "cafard", "dauphin")
    attributes = ("rose", "noir", "abile", "séché", "salubre", "émue", "sucré")
    a = [Symbol("_" * name * "_" * attribute) for name in names, attribute in attributes]
    tuple(shuffle(a)...)
end

let
    # Generate fast index lookup function with a generated list
    # of if ... elseif ... else nothing end.
    expr = :(if s == $(QuoteNode(first(LabeledArrays.AUTO_AXIS_NAMES))); :1; end)
    current = expr
    for (i, name) in Iterators.drop(enumerate(LabeledArrays.AUTO_AXIS_NAMES), 1)
        push!(current.args, Expr(:elseif, :(s ==$(QuoteNode(name))), :($i)))
        current = current.args[end]
    end
    push!(current.args, :(nothing))
    @eval function auto_axis_index(s::Symbol)
        $expr
    end
    @doc """ Fast index lookup into auto-generated axis names.

    Returns nothing if symbol is not found.
    """ -> auto_axis_index
end

include("AxisTuple.jl")
include("LabeledCartesianIndices.jl")
include("Structure.jl")
include("Functionalities.jl")
include("Broadcasting.jl")
end # module
