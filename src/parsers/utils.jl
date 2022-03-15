using Chain
using Dates
using JSON3
using Base: @kwdef

using Stonks: JSONContent, ContentParserError
using Stonks.Models: AbstractStonksRecord

function js_to_dict(js::JSON3.Object; key::Symbol=:raw)
  vals = Dict{Symbol,Any}()
  for (k, v) in js
    if isa(v, JSON3.Object)
      vals[k] = get(v, Symbol(key), missing)
    else
      vals[k] = v
    end
  end
  return vals
end

function apply_filters(
  data::Vector{T},
  datecol::String;
  from::Union{Date,Missing}=missing,
  to::Union{Date,Missing}=missing,
) where {T<:AbstractStonksRecord}
  return @chain data begin
    isa(from, Date) ? filter(x -> getfield(x, Symbol(datecol)) >= from, _) : _
    isa(to, Date) ? filter(x -> getfield(x, Symbol(datecol)) <= to, _) : _
  end
end

function get_remap(remaps::Union{Dict{Symbol,Symbol},Missing}, key::Symbol)
  if !ismissing(remaps)
    haskey(remaps, key) ? remaps[key] : key
  else
    key
  end
end

function parse_jsvalue(js::AbstractDict, key::Symbol, T::Any)
  if haskey(js, key)
    val = js[key]
    value = (
      if typeof(val) === T 
        val
      elseif T <: AbstractFloat && typeof(val) <: AbstractFloat
        T(val)
      else
        tryparse(T, val)
      end
    )
    return isnothing(value) ? missing : value
  end
  return missing
end

union_types(x::Union) = (x.a, union_types(x.b)...)
union_types(x::Type) = (x,)

"""
    tryparse_js(T<:AbstractStonksRecord, js; [remaps], [fixed]) -> T<:AbstractStonksRecord

Tries to convert a flat JSON3 object to a data model type by builiding it using keyword arguments.

### Arguments
- `T<:AbstractStonksRecord`: a subtype of AbstractStonksRecord in which the js object will be parsed
- `js::JSON3.Object`: needs to be a flat object

### Keywords
- `[remaps]::Dict{Symbol,Symbol}`: entries T field => js field name. Use it only for keys which don't have the same name in the js as the type.
- `[fixed]::Dict{Symbol,String}`: entries like :key => value for fields with known values, like :symbol, :id, etc. 
"""
function tryparse_js(
  ::Type{T},
  js::AbstractDict;
  remaps::Union{Dict{Symbol,Symbol},Missing}=missing,
  fixed::Union{Dict{Symbol,String},Missing}=missing,
) where {T<:AbstractStonksRecord}
  fields = @chain zip(fieldnames(T), T.types) begin
    [(field, collect(union_types(type))) for (field, type) in _]
    map(x -> (from=get_remap(remaps, x[1]), to=x[1], type=x[2]), _)
  end
  fields_req = @chain fields begin
    filter(ts -> all(map(t -> t !== Missing && t !== Nothing, ts.type)), _)
    map(first, _)
    !ismissing(remaps) ? map(from -> haskey(remaps, from) ? remaps[from] : from, _) : _
    !ismissing(fixed) ? vcat(_, keys(fixed)...) : _
  end
  js_fields = @chain [k for (k, v) in js] !ismissing(fixed) ? vcat(_, keys(fixed)...) : _
  diff = setdiff(fields_req, js_fields)
  if !isempty(diff)
    return ContentParserError("Required keys not found: $(join(diff, ", "))")
  end
  kwargs = @chain fields begin
    map(
      ts -> (
        from=ts.from,
        to=ts.to,
        type=first(filter(t -> t !== Missing && t !== Nothing, ts.type)),
      ),
      _,
    )
    Dict([k_to => parse_jsvalue(js, k_from, type) for (k_from, k_to, type) in _])
  end
  if !ismissing(fixed)
    [kwargs[k] = v for (k, v) in fixed]
  end
  return T(; kwargs...)
end
