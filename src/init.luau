-- Read this
--[[
    Resulty - A Result Type Implementation for Luau
    
    Author: yooo_ | YoheiKung (Roblox), yohei_yayoi (Discord, GitHub)
    Version: 1.0
    License: MIT License
    
    Inspired by Rust's Result<T, E> type, this module provides a robust way to handle
    operations that can succeed or fail without relying on exceptions or pcall patterns.
    
    Key Benefits:
    - Type-safe error handling with explicit success/failure states
    - Chainable operations with map, andThen, orElse
    - Pattern matching support via match()
    - Better alternative to pcall with preserved type information
    - Synchronous Promise-like chaining without callback hell
    
    Basic Usage:
        local Resulty = require(path.to.Resulty)
        
        local result = Resulty.try(function()
            return someDangerousOperation()
        end)
        
        result:match({
            Ok = function(value) print("Success:", value) end,
            Err = function(err) warn("Failed:", err) end,
        })
    
    Documentation: https://github.com/yohei_yayoi/Resulty
]]

local Resulty = {}
Resulty.__index = Resulty

--- Represents a Resulty type that can either be Ok (success) or Err (failure).
--- For old type solver compatibility, use typeof(Resulty.Ok(...)) or typeof(Resulty.Err(...))
export type Resulty<T, E> = typeof(setmetatable({} :: {
    success: boolean,
    value: T?,
    error: E?,
}, Resulty))

--- Creates a successful Resulty containing the given value.
--- @param value T -- The success value to wrap
--- @return Resulty<T, E> -- A successful Resulty
function Resulty.Ok<T>(value: T): Resulty<T, any>
    return setmetatable({
        success = true,
        value = value,
        error = nil,
    }, Resulty)
end

--- Creates a failed Resulty containing the given error.
--- @param err E -- The error value to wrap
--- @return Resulty<T, E> -- A failed Resulty
function Resulty.Err<E>(err: E): Resulty<any, E>
    return setmetatable({
        success = false,
        value = nil,
        error = err,
    }, Resulty)
end

--- Wraps a function call with automatic error handling using pcall.
--- Unlike pcall, this preserves type information and allows chaining.
--- @param fn (...any) -> T -- The function to execute
--- @param ... any -- Arguments to pass to the function
--- @return Resulty<T, string> -- Ok with return value, or Err with error message
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

--- Like try(), but prepends a context string to any error message.
--- Useful for adding meaningful context to errors.
--- @param context string -- Context description to prepend to errors
--- @param fn (...any) -> T -- The function to execute
--- @param ... any -- Arguments to pass to the function
--- @return Resulty<T, string> -- Ok with return value, or Err with contextual error
function Resulty.tryWith<T>(context: string, fn: (...any) -> T, ...: any): Resulty<T, string>
    local result = Resulty.try(fn, ...)
    if result:isErr() then
        return Resulty.Err(context .. ": " .. tostring(result.error))
    end

    return result
end

--- Combines multiple Resultys into one. Returns Ok with all values if all succeed,
--- or Err with the first failure encountered.
--- @param results {Resulty<T, E>} -- Array of Resultys to combine
--- @return Resulty<{T}, string> -- Ok with array of values, or Err with first error
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

--- Returns the first successful Resulty from an array, or the last error if all fail.
--- Similar to Promise.race but synchronous.
--- @param results {Resulty<T, E>} -- Array of Resultys to check
--- @return Resulty<T, E> -- First Ok result, or last Err if all failed
function Resulty.any<T, E>(results: { Resulty<T, E> }): Resulty<T, E | string>
    for _, result in ipairs(results) do
        if result:isOk() then
            return result
        end
    end

    return results[#results] or Resulty.Err("No results provided")
end

--- Validates a value using a predicate function.
--- @param value T -- The value to validate
--- @param validator (T) -> boolean -- Predicate function returning true if valid
--- @param errorMsg string? -- Optional custom error message
--- @return Resulty<T, string> -- Ok if valid, Err otherwise
function Resulty.validate<T>(value: T, validator: (T) -> boolean, errorMsg: string?): Resulty<T, string>
    if validator(value) then
        return Resulty.Ok(value)
    else
        return Resulty.Err(errorMsg or "Validation failed")
    end
end

--- Returns true if this Resulty is Ok (successful).
--- @return boolean
function Resulty:isOk(): boolean
    return self.success
end

--- Returns true if this Resulty is Err (failed).
--- @return boolean
function Resulty:isErr(): boolean
    return not self.success
end

--- Extracts the success value. Throws an error if this Resulty is Err.
--- @return T -- The unwrapped value
--- @error Throws if called on an Err Resulty
function Resulty:unwrap()
    if self.success then
        return self.value
    else
        error("Called unwrap on an Err value: " .. tostring(self.error))
    end
end

--- Returns the success value, or the provided default if this Resulty is Err.
--- @param default T -- Default value to return on error
--- @return T -- The value or default
function Resulty:unwrapOr<T>(default: T): T
    if self.success then
        return self.value
    else
        return default
    end
end

--- Returns the success value, or computes a default using the provided function.
--- The function receives the error value as an argument (lazy evaluation).
--- @param fn (E) -> T -- Function to compute default from error
--- @return T -- The value or computed default
function Resulty:unwrapOrElse<T, E>(fn: (E) -> T): T
    if self.success then
        return self.value
    else
        return fn(self.error)
    end
end

--- Returns the error value, or nil if this Resulty is Ok.
--- @return E? -- The error or nil
function Resulty:err()
    return self.error
end

--- Returns the success value, or nil if this Resulty is Err.
--- @return T? -- The value or nil
function Resulty:ok()
    return self.value
end

--- Pattern matches on the Resulty, calling the appropriate handler.
--- Provides exhaustive checking similar to Rust's match expression.
--- @param handlers { Ok: ((T) -> U)?, Err: ((E) -> U)? } -- Handler functions
--- @return U? -- Return value of the called handler
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

--- Transforms the success value using the provided function.
--- If this Resulty is Err, returns self unchanged.
--- @param fn (T) -> U -- Transformation function
--- @return Resulty<U, E> -- New Resulty with transformed value
function Resulty:map<T, U, E>(fn: (T) -> U): Resulty<U, E>
    if self.success then
        return Resulty.Ok(fn(self.value))
    else
        return self
    end
end

--- Transforms the error value using the provided function.
--- If this Resulty is Ok, returns self unchanged.
--- @param fn (E) -> F -- Transformation function
--- @return Resulty<T, F> -- New Resulty with transformed error
function Resulty:mapErr<T, E, F>(fn: (E) -> F): Resulty<T, F>
    if self.success then
        return self
    else
        return Resulty.Err(fn(self.error))
    end
end

--- Chains another Resulty-returning operation on success.
--- Enables flat-mapping without nested Resultys (monadic bind).
--- @param fn (T) -> Resulty<U, E> -- Function returning a new Resulty
--- @return Resulty<U, E> -- The new Resulty or self if Err
function Resulty:andThen<T, U, E>(fn: (T) -> Resulty<U, E>): Resulty<U, E>
    if self.success then
        return fn(self.value)
    else
        return self
    end
end

--- Executes a side effect on the success value without modifying the Resulty.
--- Useful for logging or debugging in a chain.
--- @param fn (T) -> () -- Side effect function
--- @return Resulty<T, E> -- Self (unchanged)
function Resulty:inspect<T>(fn: (T) -> ())
    if self.success then
        fn(self.value)
    end
	
    return self
end

--- Executes a side effect on the error value without modifying the Resulty.
--- Useful for logging or debugging errors in a chain.
--- @param fn (E) -> () -- Side effect function
--- @return Resulty<T, E> -- Self (unchanged)
function Resulty:inspectErr<E>(fn: (E) -> ())
    if not self.success then
        fn(self.error)
    end

    return self
end

--- Filters the success value using a predicate.
--- Returns Err if the predicate fails.
--- @param predicate (T) -> boolean -- Filter predicate
--- @param errorMsg string? -- Optional error message if filter fails
--- @return Resulty<T, string> -- Self if predicate passes, Err otherwise
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

--- Provides an alternative Resulty if this one is Err.
--- Enables recovery from errors with retry logic.
--- @param fn (E) -> Resulty<T, F> -- Recovery function
--- @return Resulty<T, F> -- Self if Ok, or the recovery Resulty
function Resulty:orElse<T, E, F>(fn: (E) -> Resulty<T, F>): Resulty<T, F>
    if self.success then
        return self
    else
        return fn(self.error)
    end
end

--- Converts this Resulty to a Promise-like interface for compatibility.
--- Provides andThen, catch, and await methods.
--- @return { andThen: function, catch: function, await: function }
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

--- Returns the other Resulty if this one is Ok, otherwise returns self (Err).
--- Logical AND operation for Resultys.
--- @param other Resulty<U, E> -- The other Resulty
--- @return Resulty<U, E> -- other if self is Ok, self otherwise
function Resulty:and_<U, E>(other: Resulty<U, E>): Resulty<U, E>
    if self.success then
        return other
    else
        return self
    end
end

--- Returns self if Ok, otherwise returns the other Resulty.
--- Logical OR operation for Resultys.
--- @param other Resulty<T, F> -- The fallback Resulty
--- @return Resulty<T, F> -- self if Ok, other otherwise
function Resulty:or_<T, F>(other: Resulty<T, F>): Resulty<T, F>
    if self.success then
        return self
    else
        return other
    end
end

return Resulty