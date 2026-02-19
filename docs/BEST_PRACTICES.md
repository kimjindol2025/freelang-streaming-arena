# 🎯 Best Practices

Optimization patterns and guidelines for Streaming Arena.

---

## 1. Memory Management

### ✅ DO: Use Move Semantics

```freelang
// GOOD: insight moved, not copied
fn process_insight(
  state: &AnalyticsState,
  insight: Insight  // ← No copy
) -> AnalyticsState {
  // ... process ...
}
```

**Why**: Zero copy overhead, O(1) space

### ❌ DON'T: Copy Insights Unnecessarily

```freelang
// BAD: Copying insight
let insight_copy = insight_original
// Now two insights in memory (96 bytes)
```

**Why**: Doubles memory, breaks O(1) guarantee

### ✅ DO: Use References for Read-Only Access

```freelang
// GOOD: Reference for reading only
fn is_anomaly(insight: &Insight, baseline: f64) -> bool {
  insight.value > baseline * 2.0
}
```

**Why**: No copy, no ownership transfer

---

## 2. Stream Processing Patterns

### ✅ DO: One-by-One Processing

```freelang
for i in 0..1000000 {
  let insight = generate_one(state, i)  // 1 insight
  state = process_insight(state, insight) // Process 1
  // Memory: constant
}
```

**Why**: Constant memory, predictable behavior

### ❌ DON'T: Batch Collection

```freelang
// BAD: Collect all insights first
let mut insights = []
for i in 0..1000000 {
  insights.push(generate_one(state, i))
}
// Now 1M objects = 48MB in array!
// Plus GC pressure and cache misses
```

**Why**: Defeats OOM protection

### ✅ DO: Use Generator for Data Source

```freelang
// Create source that yields one-by-one
fn fetch_from_db(index: u64) -> Insight {
  // Query database, return 1 record
  // Network latency is OK
  // Memory stays constant
}
```

**Why**: Integrates with streaming model

---

## 3. Arena Pool Management

### ✅ DO: Pre-allocate Arena Size

```freelang
// Know your peak needs
struct ArenaPool {
  pool: [Insight; 2000000],  // 96MB for 2M
  // ...
}
```

**Why**: Predictable memory, zero allocations

### ✅ DO: Monitor Utilization

```freelang
let util = arena_utilization(arena)
if util > 90.0 {
  println("WARNING: Arena 90% full")
}
```

**Why**: Early warning system

### ❌ DON'T: Dynamic Resizing

```freelang
// BAD: Resizing arena during processing
if arena.head >= arena.pool.len() {
  arena.pool.push(...)  // ← Allocation!
}
```

**Why**: Violates O(1) guarantee

---

## 4. Analytics State Management

### ✅ DO: Use Immutable Pattern

```freelang
// GOOD: Return new state
fn process_insight(
  state: &AnalyticsState,
  insight: Insight
) -> AnalyticsState {
  AnalyticsState {
    count: state.count + 1,
    sum: state.sum + insight.value,
    // ... update all fields ...
  }
}
```

**Why**: Explicit data flow, easier to reason about

### ✅ DO: Aggregate in Single Pass

```freelang
// Single loop processes and aggregates
for i in 0..1000000 {
  let insight = generate_one(state, i)
  analytics_state = process_insight(analytics_state, insight)
  // Metrics updated in-place
}
```

**Why**: No intermediate data structures

### ❌ DON'T: Multi-Pass Processing

```freelang
// BAD: Multiple passes
let metrics1 = analyze_values(insights)   // ← Pass 1
let metrics2 = analyze_health(insights)   // ← Pass 2
let metrics3 = analyze_anomalies(insights) // ← Pass 3
```

**Why**: Cache misses, extra memory traffic

---

## 5. Error Handling

### ✅ DO: Use Result Type

```freelang
// GOOD: Explicit error handling
fn arena_alloc(arena: &ArenaPool, insight: Insight) -> Result<u64, str> {
  if arena.head >= 1000000 {
    Result::Err("Arena full")
  } else {
    Result::Ok(arena.head)
  }
}
```

**Why**: FreeLang v4 standard, explicit contracts

### ✅ DO: Handle Errors at Boundaries

```freelang
// In main:
let result = arena_alloc(arena, insight)
match result {
  Result::Ok(index) => {
    // Success path
  },
  Result::Err(msg) => {
    // Error path - log and continue
    println("ERROR: {msg}")
  }
}
```

**Why**: Resilient to edge cases

### ❌ DON'T: Panic on Errors

```freelang
// BAD: Unrecoverable panic
if arena.head >= 1000000 {
  panic!("Arena overflow")  // ← Crashes entire job
}
```

**Why**: Destroys data, loses partial results

---

## 6. Benchmarking & Profiling

### ✅ DO: Measure These Metrics

```
1. Throughput: insights/sec
2. Memory: peak MB and per-insight bytes
3. CPU: % utilization
4. GC: collections/min (should be 0)
5. Latency: max/p99 ms per batch
```

### ✅ DO: Profile Memory

```bash
# Before optimization
/usr/bin/time -v ./bin/main --insights=1000000

# After optimization
/usr/bin/time -v ./bin/main --insights=1000000

# Compare:
# - Maximum resident set size (should decrease)
# - User time (should stay same or decrease)
```

**Why**: Quantify improvements

### ✅ DO: Use Realistic Data Sizes

```bash
# Test phases:
./bin/main --insights=100000    # 0.1M - quick test
./bin/main --insights=1000000   # 1M - baseline
./bin/main --insights=10000000  # 10M - scalability
```

**Why**: Identifies scalability bottlenecks

---

## 7. Parallelization (Phase 2)

### ✅ DO: Split Work Evenly

```freelang
// With 8 actors:
// Actor 1: insights 0-12.5M
// Actor 2: insights 12.5M-25M
// ...
// Actor 8: insights 87.5M-100M

// Each processes independently
// No shared state during processing
```

**Why**: Load balancing, predictable runtime

### ✅ DO: Merge Results

```freelang
// After all actors complete:
let mut final_builder = new_report_builder()
for actor_result in results {
  final_builder = add_metrics(final_builder, actor_result)
}
let final_report = build_report(final_builder, elapsed, peak_mem)
```

**Why**: Correct aggregation

### ❌ DON'T: Share State During Processing

```freelang
// BAD: Multiple actors updating same state
shared_state.count += 1  // ← Race condition!
```

**Why**: Data corruption, undefined behavior

---

## 8. Data Pipeline Patterns

### Pattern 1: Filter Before Process

```freelang
for i in 0..10000000 {
  let insight = generate_one(state, i)

  // Filter early
  if insight.status == 2 {  // Skip warnings
    continue
  }

  // Process only valid
  state = process_insight(state, insight)
}
```

**Why**: Reduces computation, maintains throughput

### Pattern 2: Batch Report

```freelang
for i in 0..10000000 {
  let insight = generate_one(state, i)
  state = process_insight(state, insight)

  // Report periodically
  if (i + 1) % 1000000 == 0 {
    let metrics = finalize_metrics(state)
    println("Progress: {progress}%, avg={metrics.avg}")
  }
}
```

**Why**: User visibility without overhead

### Pattern 3: Conditional Aggregation

```freelang
// Only track anomalies
struct AnalyticsState {
  normal_count: u64,
  anomaly_count: u64,      // ← Track separately
  anomaly_sum: f64,        // ← For anomaly avg
  anomalies: [Insight; 10000]  // ← Store up to 10K
}
```

**Why**: Reduce data volume for expensive analysis

---

## 9. Configuration Best Practices

### ✅ DO: Parameterize Configuration

```freelang
struct Config {
  total_insights: u64,
  batch_size: u64,           // For reporting
  report_interval: u64,      // Every N insights
  log_level: str,            // DEBUG/INFO/WARN/ERROR
  anomaly_threshold: f64     // Custom threshold
}
```

**Why**: Easy to tune without recompiling

### ✅ DO: Set Reasonable Defaults

```freelang
Config {
  total_insights: 1000000,    // 1M default
  batch_size: 100000,         // 10% batches
  report_interval: 100000,    // Report every 100K
  log_level: "INFO",
  anomaly_threshold: 2.0
}
```

**Why**: Works out-of-box for most cases

---

## 10. Production Checklist

Before deploying to production:

- [ ] **Memory**: Verify peak memory stays O(1)
- [ ] **Throughput**: Benchmark throughput insights/sec
- [ ] **Errors**: Handle all Result types properly
- [ ] **Monitoring**: Add health checks and metrics
- [ ] **Scaling**: Test with target data size (10M+)
- [ ] **Recovery**: Plan for partial failures
- [ ] **Logging**: Structured logs with context
- [ ] **Documentation**: Document custom extensions
- [ ] **Testing**: Unit + integration tests pass
- [ ] **Cleanup**: Remove debug prints, optimize hot paths

---

## 11. Common Mistakes

### ❌ Mistake 1: Copying Large Arrays

```freelang
// BAD
let array_copy = original_array  // ← Full copy!
```

**Fix**:
```freelang
// GOOD
fn process(arr: &[Insight]) -> bool {  // Reference
  // Process without copy
}
```

### ❌ Mistake 2: Unbounded Collections

```freelang
// BAD
let mut anomalies = []
for insight in all_insights {
  if is_anomaly(insight) {
    anomalies.push(insight)  // ← Grows unbounded
  }
}
```

**Fix**:
```freelang
// GOOD
let mut anomaly_count = 0
for insight in all_insights {
  if is_anomaly(insight) {
    anomaly_count += 1  // ← Just count
    // Or store fixed-size: if anomaly_count < 10000
  }
}
```

### ❌ Mistake 3: Nested Loops

```freelang
// BAD: O(n²)
for i in 0..1000000 {
  for j in 0..1000000 {
    // Process pair
  }
}
```

**Fix**:
```freelang
// GOOD: O(n)
for i in 0..1000000 {
  let insight = generate_one(state, i)
  state = process_insight(state, insight)
}
```

---

## 12. Optimization Checklist

When optimizing code:

1. **Measure First**: Profile before and after
2. **Focus on Hot Paths**: `process_insight()` is called 1M+ times
3. **Avoid Allocations**: Each alloc = latency + GC
4. **Use References**: Prefer `&T` to `T` when possible
5. **Batch I/O**: Group database/network calls
6. **Cache Results**: Store frequently accessed values
7. **Simplify Math**: Avoid complex calculations in loop

---

## 📊 Performance Targets

| Metric | Target | Achieved |
|--------|--------|----------|
| **1M throughput** | 250K/sec | ✅ |
| **10M throughput** | 250K/sec | ✅ |
| **Memory per 1M** | 48 MB | ✅ |
| **GC collections** | 0 | ✅ |
| **Allocations** | 0 during process | ✅ |

---

**Last Updated**: 2026-02-20
**Version**: 1.0.0-phase1
