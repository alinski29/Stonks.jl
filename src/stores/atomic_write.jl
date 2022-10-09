"""
Holds information about a single write
"""
struct WriteOperation
  data::Vector{T} where {T<:AbstractStonksRecord}
  format::String
  key::String
  filename::String
  function WriteOperation(data, format, key="", filename="data.$format")
    return new(data, format, key, filename)
  end
end

"""
Write a Vector{<:AbstractStonksRecord} to a path using a user-provided function 
  - writer(data::Vector{<:AbstractStonksRecord}, path::String)
"""
function write(op::WriteOperation, path::String, writer::Function)
  dir = "$path/$(op.key)"
  !isdir(dir) && mkpath(dir)
  filepath = "$dir/$(op.filename)"
  try
    writer(op.data, filepath)
    return (true, nothing)
  catch err
    rm(filepath; force=true)
    return (false, err)
  end
end

"""
Container of multiple `WriteOpration`s.
"""
struct WriteTransaction
  ops::Vector{WriteOperation}
  format::String
  dest::String
  tmp::String
  bkp::String
  function WriteTransaction(ops, format, dest)
    tmp_dir = "$(ensure_path(dest))/.tmp"
    bkp_dir = "$(ensure_path(dest))/.bkp"
    return new(ops, format, dest, tmp_dir, bkp_dir)
  end
end

"""
Main function that runs a transaction.
"""
function execute(tr::WriteTransaction, writer::Function)
  has_backup, bkps = backup(tr)
  success, err = write_tmp(tr, writer)
  if !success
    cleanup(tr)
    return (
      false, ErrorException("Failed to execute transaction. Write to temp directory failed")
    )
  end
  try
    commit(tr)
    # @debug "Transaction at '$(tr.dest)' with $(length(tr.ops)) atomic operations executed sucesfully."
    return (true, nothing)
  catch err
    rollback(bkps)
    return (false, err)
  finally
    cleanup(tr)
  end
end

"""
Write data to a temporary location using a user-provided function.
"""
function write_tmp(tr::WriteTransaction, writer::Function)
  isdir(tr.tmp) && rm(tr.tmp; recursive=true, force=true)
  mkpath(tr.tmp)
  tmp_writes = Channel(length(tr.ops))
  @sync begin
    for op in tr.ops
      Threads.@spawn begin
        ok, err = write(op, tr.tmp, writer)
        push!(tmp_writes, (success=ok, error=err))
      end
    end
  end
  close(tmp_writes)
  if all(map(w -> w.success, tmp_writes))
    return (true, nothing)
  else
    msg = "At least one write failed. Can't commit transaction."
    @warn msg
    return (false, ErrorException(msg))
  end
end

"""
Create a pre-transaction backup by copying everything from src to destination.
"""
function backup(tr::WriteTransaction)
  !isdir(tr.dest) && return (false, nothing)
  try
    isdir(tr.bkp) && rm(tr.bkp; recursive=true, force=true)
    mkpath(tr.bkp)
    bkps = @chain begin
      tr.ops
      map(
        op -> (
          key=!isempty(op.key) ? "$(tr.bkp)/$(op.key)" : tr.bkp,
          src=if !isempty(op.key)
            "$(tr.dest)/$(op.key)/$(op.filename)"
          else
            "$(tr.dest)/$(op.filename)"
          end,
          dest=if !isempty(op.key)
            "$(tr.bkp)/$(op.key)/$(op.filename)"
          else
            "$(tr.bkp)/$(op.filename)"
          end,
        ),
        _,
      )
    end
    @sync begin
      for bkp in bkps
        Threads.@spawn begin
          mkpath(bkp.key)
          cp(bkp.src, bkp.dest)
        end
      end
    end
    return (true, bkps)
  catch err
    return (false, err)
  end
end

"""
Copies the file from temporary to permanent location.
"""
function commit(tr::WriteTransaction)
  dir_mapping = map(
    key -> (
      src=!isempty(key) ? "$(tr.tmp)/$key" : tr.tmp,
      dest=!isempty(key) ? "$(tr.dest)/$key" : tr.dest,
    ),
    readdir(tr.tmp),
  )
  @sync begin
    for x in dir_mapping
      Threads.@spawn begin
        if isfile(x.dest)
          cp(x.src, x.dest; force=true)
        else
          !isdir(x.dest) && mkpath(x.dest)
          cp(x.src, x.dest; force=true)
        end
      end
    end
  end
end

"""
Uses the backup to revert to the original state.
"""
function rollback(backups)
  isnothing(backups) && return nothing
  @chain begin
    backups
    foreach(x -> begin
      !isdir(x.src) && mkpath(x.src)
      cp(x.dest, x.src; force=true)
    end, _)
  end
end

"""
Removes all temporary and backup files.
"""
function cleanup(tr::WriteTransaction)
  @chain begin
    [tr.bkp, tr.tmp]
    foreach(dir -> isdir(dir) && rm(dir; recursive=true, force=true), _)
  end
end
