# 📚 API Reference

Complete FreeLang v4 Streaming Arena API documentation.

---

## Insight Module (`insight.free`)

### Struct: `Insight`

```freelang
struct Insight {
  id: u64,              // Unique identifier
  timestamp: u64,       // Unix timestamp (ms)
  value: f64,           // Primary metric value
  status: u32,          // Status code (0-4)
  health_cpu: f32,      // CPU health (0-100)
  health_mem: f32,      // Memory health (0-100)
  health_disk: f32,     // Disk health (0-100)
  padding: u32          // Alignment (internal)
}
```

**Size**: 48 bytes (optimal for arena pooling)

**Fields**:
- `id`: Unique insight identifier (0-2^64-1)
- `timestamp`: Milliseconds since Unix epoch
- `value`: Primary metric (typically 0-100)
- `status`: Status code where 0=OK, 1=Warning, 2=Critical, 3=Error, 4=Unknown
- `health_cpu`: CPU utilization percentage (0.0-100.0)
- `health_mem`: Memory utilization percentage (0.0-100.0)
- `health_disk`: Disk utilization percentage (0.0-100.0)
- `padding`: Alignment bytes (reserved, always 0)

### Function: `new_insight`

**Signature**:
```freelang
fn new_insight(
  id: u64,
  timestamp: u64,
  value: f64,
  status: u32,
  cpu: f32,
  mem: f32,
  disk: f32
) -> Insight
```

**Description**: Creates a new insight with provided values.

**Parameters**:
- `id`: Unique identifier for this insight
- `timestamp`: Data collection timestamp (ms)
- `value`: Primary metric value
- `status`: Status code (0-4)
- `cpu`: CPU health percentage
- `mem`: Memory health percentage
- `disk`: Disk health percentage

**Returns**: `Insight` struct

**Example**:
```freelang
let insight = new_insight(
  1,
  1000,
  50.5,
  1,
  75.0,
  60.0,
  40.0
)
```

### Function: `format_insight`

**Signature**:
```freelang
fn format_insight(insight: &Insight) -> str
```

**Description**: Formats insight as string for logging.

**Parameters**:
- `insight`: Reference to insight

**Returns**: Formatted string representation

---

## Arena Module (`arena.free`)

### Struct: `ArenaPool`

```freelang
struct ArenaPool {
  pool: [Insight; 1000000],
  head: u64,
  tail: u64,
  allocated: u64,
  deallocated: u64
}
```

**Description**: Pre-allocated memory pool for O(1) allocation.

**Fields**:
- `pool`: Fixed 1M slot array (48MB total)
- `head`: Current write pointer (0-1M)
- `tail`: Current read pointer (0-1M)
- `allocated`: Total allocations (cumulative)
- `deallocated`: Total deallocations (cumulative)

### Function: `init_arena`

**Signature**:
```freelang
fn init_arena() -> ArenaPool
```

**Description**: Initializes empty arena pool.

**Returns**: New `ArenaPool` with all counters at 0

**Example**:
```freelang
let arena = init_arena()
```

### Function: `arena_alloc`

**Signature**:
```freelang
fn arena_alloc(arena: &ArenaPool, insight: Insight) -> Result<u64, str>
```

**Description**: Allocates slot in arena (O(1) operation).

**Parameters**:
- `arena`: Arena pool reference
- `insight`: Insight to allocate

**Returns**:
- `Result::Ok(u64)`: Index of allocated slot
- `Result::Err(str)`: "Arena full" if no slots available

**Complexity**: O(1) time, O(1) space

### Function: `arena_utilization`

**Signature**:
```freelang
fn arena_utilization(arena: &ArenaPool) -> f64
```

**Description**: Returns current pool utilization percentage.

**Parameters**:
- `arena`: Arena pool reference

**Returns**: Percentage (0.0-100.0)

**Example**:
```freelang
let util = arena_utilization(arena)  // 45.5 means 45.5% used
```

### Function: `arena_reset`

**Signature**:
```freelang
fn arena_reset(arena: &ArenaPool) -> ArenaPool
```

**Description**: Resets arena for next batch without losing statistics.

**Parameters**:
- `arena`: Arena to reset

**Returns**: New arena with head/tail reset but allocated/deallocated preserved

### Struct: `ArenaStats`

```freelang
struct ArenaStats {
  total_allocated: u64,
  total_deallocated: u64,
  current_utilization: f64,
  peak_utilization: f64
}
```

**Description**: Arena statistics snapshot.

### Function: `arena_stats`

**Signature**:
```freelang
fn arena_stats(arena: &ArenaPool) -> ArenaStats
```

**Returns**: Current statistics

---

## Generator Module (`generator.free`)

### Struct: `GeneratorConfig`

```freelang
struct GeneratorConfig {
  total_count: u64,
  batch_size: u64,
  interval_ms: u64
}
```

**Fields**:
- `total_count`: Total insights to generate
- `batch_size`: Logical batch size (for reporting)
- `interval_ms`: Milliseconds between batches (0 = no delay)

### Struct: `GeneratorState`

```freelang
struct GeneratorState {
  current: u64,
  total: u64,
  batch_size: u64,
  generated: u64,
  start_time: u64
}
```

**Fields**:
- `current`: Current iteration position
- `total`: Total count to generate
- `batch_size`: Batch size from config
- `generated`: Total generated so far
- `start_time`: Generation start timestamp

### Function: `init_generator`

**Signature**:
```freelang
fn init_generator(config: GeneratorConfig) -> GeneratorState
```

**Description**: Initializes generator state.

**Returns**: New `GeneratorState`

### Function: `generate_one`

**Signature**:
```freelang
fn generate_one(state: &GeneratorState, index: u64) -> Insight
```

**Description**: Generates single insight at index (deterministic).

**Parameters**:
- `state`: Generator state
- `index`: Index (0-based)

**Returns**: Insight with deterministic values based on index

**Algorithm**:
```
timestamp = start_time + (index * 1000)
value = index % 100
status = index % 5
cpu = (index % 80) + 10
mem = (index % 70) + 20
disk = (index % 60) + 30
```

**Complexity**: O(1) - no allocations, deterministic calculation

### Function: `is_complete`

**Signature**:
```freelang
fn is_complete(state: &GeneratorState) -> bool
```

**Returns**: true if current >= total

### Function: `progress_percent`

**Signature**:
```freelang
fn progress_percent(state: &GeneratorState) -> f64
```

**Returns**: Progress percentage (0.0-100.0)

---

## Analytics Module (`analytics.free`)

### Struct: `AnalyticsMetrics`

```freelang
struct AnalyticsMetrics {
  count: u64,
  sum: f64,
  min: f64,
  max: f64,
  avg: f64,
  cpu_avg: f32,
  mem_avg: f32,
  disk_avg: f32
}
```

**Description**: Computed analytics metrics.

### Struct: `AnalyticsState`

```freelang
struct AnalyticsState {
  count: u64,
  sum: f64,
  min: f64,
  max: f64,
  cpu_sum: f32,
  mem_sum: f32,
  disk_sum: f32,
  errors: u64
}
```

**Description**: Running analytics state.

### Function: `init_analytics`

**Signature**:
```freelang
fn init_analytics() -> AnalyticsState
```

**Returns**: New analytics state (all zeros)

### Function: `process_insight`

**Signature**:
```freelang
fn process_insight(state: &AnalyticsState, insight: Insight) -> AnalyticsState
```

**Description**: Processes single insight with **move semantics** (no copy).

**Parameters**:
- `state`: Current analytics state
- `insight`: Insight to process (moved, not copied)

**Returns**: Updated analytics state

**Complexity**: O(1) time, O(1) space, **0 allocations**

**Key Insight**: The `insight` parameter is *moved* not copied. This is the critical optimization that enables 100M+ processing.

### Function: `finalize_metrics`

**Signature**:
```freelang
fn finalize_metrics(state: &AnalyticsState) -> AnalyticsMetrics
```

**Description**: Computes final metrics from state.

**Returns**: `AnalyticsMetrics` with averages calculated

### Function: `is_anomaly`

**Signature**:
```freelang
fn is_anomaly(insight: &Insight, baseline: f64) -> bool
```

**Description**: Checks if insight exceeds 2x baseline.

**Parameters**:
- `insight`: Insight to check (reference)
- `baseline`: Baseline value

**Returns**: true if insight.value > baseline * 2.0

---

## Reporter Module (`reporter.free`)

### Struct: `Report`

```freelang
struct Report {
  total_count: u64,
  total_sum: f64,
  min_value: f64,
  max_value: f64,
  avg_value: f64,
  cpu_avg: f32,
  mem_avg: f32,
  disk_avg: f32,
  processing_time_ms: u64,
  throughput: f64,
  memory_peak_mb: f64
}
```

**Description**: Final report with all aggregated metrics.

### Struct: `ReportBuilder`

```freelang
struct ReportBuilder {
  total_count: u64,
  total_sum: f64,
  min_value: f64,
  max_value: f64,
  cpu_sum: f32,
  mem_sum: f32,
  disk_sum: f32,
  start_time: u64,
  peak_memory: f64
}
```

**Description**: Accumulator for building reports.

### Function: `new_report_builder`

**Signature**:
```freelang
fn new_report_builder() -> ReportBuilder
```

**Returns**: New empty builder

### Function: `add_metrics`

**Signature**:
```freelang
fn add_metrics(
  builder: &ReportBuilder,
  metrics: &AnalyticsMetrics
) -> ReportBuilder
```

**Description**: Adds metrics from one analytics engine to builder.

**Use case**: When aggregating results from multiple actors

### Function: `build_report`

**Signature**:
```freelang
fn build_report(
  builder: &ReportBuilder,
  elapsed_ms: u64,
  peak_memory_mb: f64
) -> Report
```

**Description**: Builds final report.

**Parameters**:
- `builder`: Accumulated metrics
- `elapsed_ms`: Total processing time
- `peak_memory_mb`: Peak memory usage

**Returns**: Final `Report`

**Calculations**:
```
throughput = total_count / elapsed_ms * 1000.0  // insights/sec
avg_value = total_sum / total_count
cpu_avg = cpu_sum / total_count
mem_avg = mem_sum / total_count
disk_avg = disk_sum / total_count
```

### Function: `format_report`

**Signature**:
```freelang
fn format_report(report: &Report) -> str
```

**Returns**: Formatted string report

### Function: `print_report`

**Signature**:
```freelang
fn print_report(report: &Report) -> bool
```

**Description**: Prints report to stdout.

**Returns**: true on success

---

## Type Definitions

### Result<T, E>

FreeLang v4 built-in result type.

**Variants**:
- `Result::Ok(T)`: Success case
- `Result::Err(E)`: Error case

**Example**:
```freelang
let result: Result<u64, str> = arena_alloc(arena, insight)
match result {
  Result::Ok(index) => println("Allocated at {index}"),
  Result::Err(msg) => println("Error: {msg}")
}
```

---

## Constants

```freelang
const INSIGHT_SIZE: u64 = 48        // Bytes per insight
const ARENA_POOL_SIZE: u64 = 1000000  // Max insights in pool
```

---

## Performance Notes

| Operation | Complexity | Allocations |
|-----------|-----------|-------------|
| `new_insight` | O(1) | 0 |
| `arena_alloc` | O(1) | 0 |
| `generate_one` | O(1) | 0 |
| `process_insight` | O(1) | 0 |
| `finalize_metrics` | O(1) | 0 |
| `build_report` | O(1) | 0 |

**Total stream processing (1M insights)**:
- Time: ~40 seconds
- Memory: 48 bytes/iteration = 48MB fixed
- Allocations: 0 (arena pre-allocated)
- GC pressure: 0

---

**Last Updated**: 2026-02-20
**FreeLang Version**: v2.0.0-phase11
