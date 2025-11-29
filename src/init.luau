--[[
    Resulty - Result Type for Luau
    
    By: yooo_ | YoheiKung (Roblox), yohei_yayoi (Discord, GitHub)
    Version: 1.0
    License: MIT
    
    Basically Rust's Result<T, E> but for Luau. Lets you handle stuff that might
    fail without dealing with pcall's awkward return values or throwing errors everywhere.
    
    Why use this?
    - No more "did pcall return true or false?" confusion
    - Chain operations together nicely
    - Pattern matching with match()
    - Types actually work
    
    Quick example:
        local Resulty = require(path.to.Resulty)
        
        local result = Resulty.try(function()
            return someDangerousOperation()
        end)
        
        result:match({
            Ok = function(value) print("Got:", value) end,
            Err = function(err) warn("Oops:", err) end,
        })
    
    Docs: https://github.com/yohei_yayoi/Resulty
]]

local Resulty = {}
Resulty.__index = Resulty

-- The main type. Use typeof(Resulty.Ok(...)) for old type solver.
export type Resulty<T, E> = typeof(setmetatable({} :: {
    success: boolean,
    value: T?,
    error: E?,
}, Resulty))

-- Wrap a value as a success
function Resulty.Ok<T>(value: T): Resulty<T, any>
    return setmetatable({
        success = true,
        value = value,
        error = nil,
    }, Resulty)
end

-- Wrap an error as a failure
function Resulty.Err<E>(err: E): Resulty<any, E>
    return setmetatable({
        success = false,
        value = nil,
        error = err,
    }, Resulty)
end

-- pcall wrapper that returns a Resulty instead of (bool, value)
function Resulty.try<T>(fn: (...any) -> T, ...: any): Resulty<T, string>
    local args = { ... }
    local success, resultValue = pcall(function()
        return fn(table.unpack(args))
    end)

    if success then
        return Resulty.Ok(resultValue)
    else
        return Resulty.Err(resultValue)
    end
end

-- Same as try() but adds context to error messages (e.g. "Loading config: failed to parse")
function Resulty.tryWith<T>(context: string, fn: (...any) -> T, ...: any): Resulty<T, string>
    local result = Resulty.try(fn, ...)
    if result:isErr() then
        return Resulty.Err(context .. ": " .. tostring(result.error))
    end

    return result
end

-- Combine multiple Resultys - Ok if all succeed, Err on first failure
function Resulty.all<T, E>(results: { Resulty<T, E> }): Resulty<{ T }, string>
    local values = {}
    for i, result in ipairs(results) do
        if result:isErr() then
            return Resulty.Err("Operation " .. i .. " failed: " .. tostring(result.error))
        end
        table.insert(values, result.value)
    end

    return Resulty.Ok(values)
end

-- Return the first success, or the last error if everything failed
function Resulty.any<T, E>(results: { Resulty<T, E> }): Resulty<T, E | string>
    for _, result in ipairs(results) do
        if result:isOk() then
            return result
        end
    end

    return results[#results] or Resulty.Err("No results provided")
end

-- Quick validation helper - returns Ok(value) if validator returns true
function Resulty.validate<T>(value: T, validator: (T) -> boolean, errorMsg: string?): Resulty<T, string>
    if validator(value) then
        return Resulty.Ok(value)
    else
        return Resulty.Err(errorMsg or "Validation failed")
    end
end

-- Check if this is a success
function Resulty:isOk(): boolean
    return self.success
end

-- Check if this is an error
function Resulty:isErr(): boolean
    return not self.success
end

-- Get the value or explode if it's an error
function Resulty:unwrap()
    if self.success then
        return self.value
    else
        error("Called unwrap on an Err value: " .. tostring(self.error))
    end
end

-- Get the value or use a fallback
function Resulty:unwrapOr<T>(default: T): T
    if self.success then
        return self.value
    else
        return default
    end
end

-- Get the value, or compute a fallback from the error (lazy version of unwrapOr)
function Resulty:unwrapOrElse<T, E>(fn: (E) -> T): T
    if self.success then
        return self.value
    else
        return fn(self.error)
    end
end

-- Get the error (nil if this is Ok)
function Resulty:err()
    return self.error
end

-- Get the value (nil if this is Err)
function Resulty:ok()
    return self.value
end

-- Pattern match like Rust - call Ok handler or Err handler based on state
function Resulty:match<T, E, U>(handlers: { Ok: ((T) -> U)?, Err: ((E) -> U)? }): U?
    if self.success then
        if handlers.Ok then
            return handlers.Ok(self.value)
        end
    else
        if handlers.Err then
            return handlers.Err(self.error)
        end
    end

    return nil
end

-- Transform the success value (does nothing if Err)
function Resulty:map<T, U, E>(fn: (T) -> U): Resulty<U, E>
    if self.success then
        return Resulty.Ok(fn(self.value))
    else
        return self
    end
end

-- Transform the error value (does nothing if Ok)
function Resulty:mapErr<T, E, F>(fn: (E) -> F): Resulty<T, F>
    if self.success then
        return self
    else
        return Resulty.Err(fn(self.error))
    end
end

-- Chain another operation that also returns a Resulty (flatMap basically)
function Resulty:andThen<T, U, E>(fn: (T) -> Resulty<U, E>): Resulty<U, E>
    if self.success then
        return fn(self.value)
    else
        return self
    end
end

-- Peek at the value without changing anything (good for logging)
function Resulty:inspect<T>(fn: (T) -> ())
    if self.success then
        fn(self.value)
    end
	
    return self
end

-- Peek at the error without changing anything
function Resulty:inspectErr<E>(fn: (E) -> ())
    if not self.success then
        fn(self.error)
    end

    return self
end

-- Keep the value only if it passes the predicate, otherwise turn into Err
function Resulty:filter<T>(predicate: (T) -> boolean, errorMsg: string?): Resulty<T, string>
    if self.success then
        if predicate(self.value) then
            return self
        else
            return Resulty.Err(errorMsg or "Filter predicate failed")
        end
    else
        return self
    end
end

-- Try to recover from an error with a fallback operation
function Resulty:orElse<T, E, F>(fn: (E) -> Resulty<T, F>): Resulty<T, F>
    if self.success then
        return self
    else
        return fn(self.error)
    end
end

-- Make it look like a Promise if you're into that
function Resulty:asPromise()
    local self_ = self
    return {
        andThen = function(_, onSuccess, onFailure)
            if self_.success and onSuccess then
                return Resulty.Ok(onSuccess(self_.value)):asPromise()
            elseif not self_.success and onFailure then
                return Resulty.Ok(onFailure(self_.error)):asPromise()
            end
            return self_:asPromise()
        end,
        catch = function(_, onFailure)
            if not self_.success and onFailure then
                return Resulty.Ok(onFailure(self_.error)):asPromise()
            end
            return self_:asPromise()
        end,
        await = function(_)
            return self_:unwrap()
        end,
    }
end

-- Return the other Resulty if this one is Ok (logical AND)
function Resulty:and_<U, E>(other: Resulty<U, E>): Resulty<U, E>
    if self.success then
        return other
    else
        return self
    end
end

-- Return self if Ok, otherwise return the other one (logical OR)
function Resulty:or_<T, F>(other: Resulty<T, F>): Resulty<T, F>
    if self.success then
        return self
    else
        return other
    end
end

return Resulty