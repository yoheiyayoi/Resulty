# Resulty ⚡

A **type-safe Result type implementation** for Luau, inspired by Rust's `Result<T, E>`.

Handle operations that can succeed or fail without relying on exceptions or messy `pcall` patterns.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- **Type-safe error handling** with explicit success/failure states
- **Chainable operations** with `map`, `andThen`, `orElse`
- **Pattern matching** support via `match()`
- **Better alternative to pcall** with preserved type information
- **Promise-like chaining** without callback hell (synchronous)

## 📦 Installation

### Wally

Add to your `wally.toml`:

```toml
[dependencies]
Resulty = "yohei_yayoi/resulty@1.0.0"
```

### Manual

Copy `src/init.luau` into your project.

---

## 🚀 Quick Start

```luau
local Resulty = require(path.to.Resulty)

-- Wrap a potentially dangerous operation
local result = Resulty.try(function()
    return someDangerousOperation()
end)

-- Handle the result with pattern matching
result:match({
    Ok = function(value) print("Success:", value) end,
    Err = function(err) warn("Failed:", err) end,
})
```

---

## 📖 API Reference

### Creating Results

#### `Resulty.Ok(value)`
Creates a successful Result containing the given value.

```luau
local success = Resulty.Ok("Hello!")
print(success:unwrap()) -- "Hello!"
```

#### `Resulty.Err(error)`
Creates a failed Result containing the given error.

```luau
local failure = Resulty.Err("Something went wrong")
print(failure:isErr()) -- true
```

#### `Resulty.try(fn, ...)`
Wraps a function call with automatic error handling using `pcall`. Unlike raw pcall, this preserves type information and allows chaining.

```luau
local result = Resulty.try(function()
    return game.Workspace:FindFirstChild("Part").Name
end)
-- If Part doesn't exist, result will be Err instead of throwing
```

#### `Resulty.tryWith(context, fn, ...)`
Like `try()`, but prepends a context string to any error message.

```luau
local result = Resulty.tryWith("Loading player data", function()
    return DataStore:GetAsync(key)
end)
-- Error: "Loading player data: DataStore request failed"
```

#### `Resulty.validate(value, validator, errorMsg?)`
Validates a value using a predicate function.

```luau
local result = Resulty.validate(age, function(v) return v >= 18 end, "Must be 18+")
```

---

### Combining Multiple Results

#### `Resulty.all(results)`
Combines multiple Results into one. Returns `Ok` with all values if all succeed, or `Err` with the first failure.

```luau
local results = Resulty.all({
    Resulty.Ok(1),
    Resulty.Ok(2),
    Resulty.Ok(3),
})
-- Ok({1, 2, 3})
```

#### `Resulty.any(results)`
Returns the first successful Result, or the last error if all fail.

```luau
local result = Resulty.any({
    Resulty.Err("Failed 1"),
    Resulty.Ok("Success!"),
    Resulty.Err("Failed 2"),
})
-- Ok("Success!")
```

---

### Checking State

#### `:isOk()`
Returns `true` if the Result is successful.

```luau
if result:isOk() then
    print("It worked!")
end
```

#### `:isErr()`
Returns `true` if the Result is an error.

```luau
if result:isErr() then
    warn("Something failed")
end
```

---

### Extracting Values

#### `:unwrap()`
Extracts the success value. **Throws an error** if the Result is `Err`.

```luau
local value = result:unwrap() -- ⚠️ Will error if result is Err!
```

#### `:unwrapOr(default)`
Returns the success value, or the provided default if `Err`.

```luau
local name = result:unwrapOr("Unknown")
```

#### `:unwrapOrElse(fn)`
Returns the success value, or computes a default using the provided function (lazy evaluation).

```luau
local value = result:unwrapOrElse(function(err)
    warn("Error occurred:", err)
    return getDefaultValue()
end)
```

#### `:ok()`
Returns the success value, or `nil` if `Err`.

```luau
local maybeValue = result:ok()
```

#### `:err()`
Returns the error value, or `nil` if `Ok`.

```luau
local maybeError = result:err()
```

---

### Pattern Matching

#### `:match(handlers)`
Pattern matches on the Result, calling the appropriate handler. Provides exhaustive checking similar to Rust's `match` expression.

```luau
local message = result:match({
    Ok = function(value)
        return "Got: " .. tostring(value)
    end,
    Err = function(err)
        return "Error: " .. tostring(err)
    end,
})
```

---

### Transforming Values

#### `:map(fn)`
Transforms the success value using the provided function. If `Err`, returns self unchanged.

```luau
local doubled = Resulty.Ok(5):map(function(n) return n * 2 end)
-- Ok(10)
```

#### `:mapErr(fn)`
Transforms the error value. If `Ok`, returns self unchanged.

```luau
local detailed = result:mapErr(function(err)
    return { code = 500, message = err }
end)
```

#### `:filter(predicate, errorMsg?)`
Filters the success value using a predicate. Returns `Err` if the predicate fails.

```luau
local evenOnly = Resulty.Ok(5):filter(function(n) return n % 2 == 0 end, "Must be even")
-- Err("Must be even")
```

---

### Chaining Operations

#### `:andThen(fn)`
Chains another Result-returning operation on success. Enables flat-mapping without nested Results (monadic bind).

```luau
local result = Resulty.Ok(userId)
    :andThen(function(id)
        return Resulty.try(function()
            return DataStore:GetAsync(id)
        end)
    end)
    :andThen(function(data)
        return Resulty.validate(data, isValid, "Invalid data")
    end)
```

#### `:orElse(fn)`
Provides an alternative Result if this one is `Err`. Enables recovery from errors with retry logic.

```luau
local result = fetchFromPrimary()
    :orElse(function(err)
        warn("Primary failed:", err)
        return fetchFromBackup()
    end)
```

---

### Side Effects (Debugging)

#### `:inspect(fn)`
Executes a side effect on the success value without modifying the Result. Useful for logging.

```luau
result
    :inspect(function(value) print("Got value:", value) end)
    :map(processValue)
```

#### `:inspectErr(fn)`
Executes a side effect on the error value without modifying the Result.

```luau
result
    :inspectErr(function(err) warn("Error:", err) end)
    :orElse(recover)
```

---

### Logical Operations

#### `:and_(other)`
Returns the other Result if this one is `Ok`, otherwise returns self (`Err`).

```luau
local both = resultA:and_(resultB)
-- Returns resultB if resultA is Ok, otherwise returns resultA
```

#### `:or_(other)`
Returns self if `Ok`, otherwise returns the other Result.

```luau
local either = resultA:or_(resultB)
-- Returns resultA if Ok, otherwise returns resultB
```

---

### Promise Compatibility

#### `:asPromise()`
Converts the Result to a Promise-like interface for compatibility.

```luau
result:asPromise()
    :andThen(function(value)
        return value * 2
    end)
    :catch(function(err)
        warn("Error:", err)
        return 0
    end)
```

---

## 💡 Examples

### Safe Data Loading

```luau
local function loadPlayerData(player)
    return Resulty.tryWith("Loading " .. player.Name, function()
        return DataStore:GetAsync(player.UserId)
    end)
    :andThen(function(data)
        return Resulty.validate(data, function(d)
            return d ~= nil and d.version ~= nil
        end, "Invalid data format")
    end)
    :map(function(data)
        return migrateData(data)
    end)
end

loadPlayerData(player):match({
    Ok = function(data)
        applyData(player, data)
    end,
    Err = function(err)
        warn(err)
        applyDefaultData(player)
    end,
})
```

### Chaining Multiple Operations

```luau
local result = Resulty.Ok(rawInput)
    :map(sanitize)
    :filter(isValidFormat, "Invalid format")
    :andThen(function(input)
        return Resulty.try(function()
            return parseJson(input)
        end)
    end)
    :inspect(function(parsed)
        print("Successfully parsed:", parsed)
    end)
    :unwrapOr({})
```

### Error Recovery

```luau
local config = Resulty.try(loadFromFile)
    :orElse(function()
        return Resulty.try(loadFromNetwork)
    end)
    :orElse(function()
        return Resulty.Ok(DEFAULT_CONFIG)
    end)
    :unwrap()
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 👤 Author
**yooo_**
**YoheiKung** (Roblox)  
**yohei_yayoi** (Discord, GitHub)
