# Resulty

Rust-style Result type for Luau. No more `pcall` spaghetti.

## Why?

Ever get tired of writing this?

```luau
local ok, result = pcall(function()
    return something:ThatMightFail()
end)

if ok then
    -- do stuff
else
    -- handle error
end
```

Yeah, me too. This gives you proper error handling that you can actually chain together.

## Install

**Wally:**
```toml
[dependencies]
Resulty = "yohei_yayoi/resulty@1.0.0"
```

Or just grab `src/init.luau` and drop it in your project.

## Quick Example

```luau
local Resulty = require(path.to.Resulty)

local result = Resulty.try(function()
    return somethingRisky()
end)

result:match({
    Ok = function(value) print("got:", value) end,
    Err = function(err) warn("oops:", err) end,
})
```

## API

### Making Results

**`Resulty.Ok(value)`** - wrap a success value
```luau
local good = Resulty.Ok("nice")
```

**`Resulty.Err(error)`** - wrap an error
```luau
local bad = Resulty.Err("something broke")
```

**`Resulty.try(fn, ...)`** - pcall but better
```luau
local result = Resulty.try(function()
    return workspace:FindFirstChild("Part").Name
end)
```

**`Resulty.tryWith(context, fn, ...)`** - same as try but adds context to errors
```luau
local result = Resulty.tryWith("loading data", function()
    return DataStore:GetAsync(key)
end)
-- if it fails: "loading data: [actual error]"
```

**`Resulty.validate(value, check, errMsg?)`** - validate something
```luau
local result = Resulty.validate(age, function(v) return v >= 18 end, "too young")
```

### Combining Results

**`Resulty.all(results)`** - all must succeed, returns array of values
```luau
local all = Resulty.all({
    Resulty.Ok(1),
    Resulty.Ok(2),
})
-- Ok({1, 2})
```

**`Resulty.any(results)`** - returns first success
```luau
local first = Resulty.any({
    Resulty.Err("nope"),
    Resulty.Ok("this one"),
})
```

### Checking

**`:isOk()`** / **`:isErr()`** - what it sounds like

### Getting Values Out

**`:unwrap()`** - get the value or explode
```luau
local val = result:unwrap() -- errors if result is Err!
```

**`:unwrapOr(default)`** - get the value or use fallback
```luau
local name = result:unwrapOr("Unknown")
```

**`:unwrapOrElse(fn)`** - get the value or compute fallback
```luau
local val = result:unwrapOrElse(function(err)
    warn(err)
    return getFallback()
end)
```

**`:ok()`** / **`:err()`** - returns value/error or nil

### Pattern Matching

**`:match(handlers)`** - handle both cases
```luau
result:match({
    Ok = function(v) return "got " .. v end,
    Err = function(e) return "failed: " .. e end,
})
```

### Transforming

**`:map(fn)`** - transform success value
```luau
Resulty.Ok(5):map(function(n) return n * 2 end) -- Ok(10)
```

**`:mapErr(fn)`** - transform error value

**`:filter(predicate, errMsg?)`** - keep value if predicate passes
```luau
Resulty.Ok(5):filter(function(n) return n % 2 == 0 end, "not even")
-- Err("not even")
```

### Chaining

**`:andThen(fn)`** - chain operations (fn must return a Result)
```luau
Resulty.Ok(userId)
    :andThen(function(id)
        return Resulty.try(function()
            return DataStore:GetAsync(id)
        end)
    end)
```

**`:orElse(fn)`** - try recovery on error
```luau
fetchPrimary()
    :orElse(function(err)
        warn("primary failed:", err)
        return fetchBackup()
    end)
```

### Debugging

**`:inspect(fn)`** - peek at success value (for logging)
```luau
result:inspect(function(v) print("got:", v) end)
```

**`:inspectErr(fn)`** - peek at error value

### Logic

**`:and_(other)`** - returns other if self is Ok
**`:or_(other)`** - returns other if self is Err

### Promise-ish

**`:asPromise()`** - if you want that interface
```luau
result:asPromise()
    :andThen(function(v) return v * 2 end)
    :catch(function(e) return 0 end)
```

## Real Example

```luau
local function loadPlayerData(player)
    return Resulty.tryWith("loading " .. player.Name, function()
        return DataStore:GetAsync(player.UserId)
    end)
    :andThen(function(data)
        return Resulty.validate(data, function(d)
            return d ~= nil and d.version ~= nil
        end, "bad data format")
    end)
    :map(migrateData)
end

loadPlayerData(player):match({
    Ok = function(data) applyData(player, data) end,
    Err = function(err)
        warn(err)
        applyDefaults(player)
    end,
})
```

## License

MIT

## Author
yooo_ / YoheiKung (Roblox) / yohei_yayoi (Discord, GitHub)
