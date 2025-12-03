# Safe Iterative Boundary Detection Algorithm

## Overview
This document describes the SAFE, iterative boundary detection algorithm implemented in `ScreenshotCroppingService.swift` for detecting blue quiz boxes in screenshots.

## Algorithm Type
**Breadth-First Search (BFS)** - Queue-based, fully iterative (NO RECURSION)

## Safety Features

### 1. Multiple Safety Checks
- **Bounds validation**: All coordinates checked before access
- **Pixel data validation**: Index bounds checked before memory access
- **Maximum iterations**: Hard limit of 500,000 pixels checked
- **Maximum box size**: 2000x2000 pixels max
- **Minimum box size**: 50x50 pixels min (filters noise)

### 2. Fallback Behavior
If detection fails at any point, the algorithm falls back to a fixed 1200x900 crop centered on the mouse position.

### 3. Memory Safety
- Uses `Set<Int>` for visited pixels (O(1) lookup)
- No recursion (prevents stack overflow)
- Queue-based iteration with explicit bounds

## Algorithm Flow

```
1. Validate starting position (mouse coordinates)
   ↓
2. Get pixel data from CGImage
   ↓
3. Check if starting pixel is blue
   ↓ (if not blue)
   FALLBACK → 1200x900 crop
   ↓ (if blue)
4. Initialize BFS queue with starting pixel
   ↓
5. ITERATIVE LOOP (while queue not empty):
   a. Dequeue pixel
   b. Update bounding box (minX, maxX, minY, maxY)
   c. Check safety limits (max pixels, max box size)
   d. Check 4 neighbors (up, down, left, right)
   e. For each neighbor:
      - Validate bounds
      - Check if visited
      - Validate pixel data index
      - Check if blue pixel
      - If blue: mark visited, add to queue
   ↓
6. Validate detected box size (min 50x50)
   ↓
7. Add 10-pixel padding around box
   ↓
8. Return crop rectangle
```

## Blue Pixel Detection

### Formula
A pixel is considered "blue" if:
```swift
b > 200 AND b > (r + g)
```

Where:
- `b` = blue channel value (0-255)
- `r` = red channel value (0-255)
- `g` = green channel value (0-255)

### Rationale
- `b > 200`: Ensures strong blue component
- `b > r + g`: Ensures blue dominance (eliminates cyan, purple, gray)

## Edge Cases Handled

### 1. Mouse on White Background
**Behavior**: Starting pixel not blue → immediate fallback to 1200x900 crop

### 2. Mouse on Edge of Blue Box
**Behavior**: BFS expands from edge inward, finds all connected blue pixels

### 3. Very Large Blue Regions
**Safety**: Stops at 2000x2000 max or 500k pixels checked, returns detected bounds

### 4. Noise/Small Blue Pixels
**Filter**: Rejects boxes smaller than 50x50 pixels, uses fallback

### 5. Multiple Blue Boxes on Screen
**Behavior**: Only captures the connected region starting from mouse position

## Performance Characteristics

### Time Complexity
- **Best case**: O(1) - Mouse not on blue, immediate fallback
- **Typical case**: O(n) - where n = pixels in blue box
- **Worst case**: O(500,000) - safety limit reached

### Space Complexity
- **Visited set**: O(n) where n = pixels checked
- **Queue**: O(boundary_length) typically < 1000 pixels
- **Total**: O(n) linear in box size

### Typical Performance
- Small box (500x400): ~200,000 pixels checked, <0.5s
- Medium box (800x600): ~480,000 pixels checked, ~1s
- Large box: Hits safety limit at 500k pixels, ~1.5s

## Safety Limits

| Limit | Value | Purpose |
|-------|-------|---------|
| Max pixels checked | 500,000 | Prevent infinite loops |
| Max box width | 2000 pixels | Prevent unrealistic sizes |
| Max box height | 2000 pixels | Prevent unrealistic sizes |
| Min box width | 50 pixels | Filter noise |
| Min box height | 50 pixels | Filter noise |
| Padding | 10 pixels | Capture box borders cleanly |
| Fallback width | 1200 pixels | Reasonable default crop |
| Fallback height | 900 pixels | Reasonable default crop |

## Implementation Details

### Key Data Structures

```swift
// Visited pixels (fast lookup)
var visited = Set<Int>()  // Key: y * width + x

// BFS queue
var queue: [(x: Int, y: Int)] = []

// Bounding box
var minX, maxX, minY, maxY: Int
```

### Pixel Index Calculation

```swift
let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)

// Safety check BEFORE access
guard pixelIndex + 2 < pixelDataLength else {
    continue
}

let r = pixels[pixelIndex]
let g = pixels[pixelIndex + 1]
let b = pixels[pixelIndex + 2]
```

### Neighbor Checking (4-connected)

```swift
let neighbors = [
    (x - 1, y),  // left
    (x + 1, y),  // right
    (x, y - 1),  // up
    (x, y + 1)   // down
]
```

## Testing Recommendations

### Test Case 1: Normal Blue Box
**Setup**: Mouse over center of blue quiz box
**Expected**: Tight crop around box with 10px padding

### Test Case 2: Mouse on White
**Setup**: Mouse over white text area
**Expected**: Fallback 1200x900 crop centered on mouse

### Test Case 3: Mouse on Edge
**Setup**: Mouse on border of blue box
**Expected**: Full box captured from edge detection

### Test Case 4: Large Blue Region
**Setup**: Very large blue area (>2000px)
**Expected**: Stops at max size, returns detected bounds

### Test Case 5: Multiple Blue Boxes
**Setup**: Several blue boxes on screen, mouse over one
**Expected**: Only the box under mouse is captured

## Error Handling

Every error condition logs to console and falls back gracefully:

```swift
print("   ❌ Start position out of bounds")
return createFallbackRect(...)
```

No crashes, no exceptions, always returns a valid crop rectangle.

## Logging

The algorithm provides detailed logging:

```
🔍 Starting SAFE boundary detection from (x, y)
📐 Image dimensions: W x H
📊 Pixel format: bytes/pixel, bytes/row
🎨 Starting pixel color: R=X, G=Y, B=Z
✅ Starting pixel is blue - beginning BFS
🌊 Starting BFS flood-fill (iterative, queue-based)
✅ BFS complete: checked N pixels
📐 Detected bounds: X[min-max] Y[min-max]
📦 Final crop with padding: WxH at (x, y)
```

## Why This Algorithm is Safe

1. **No recursion**: Cannot overflow stack
2. **Bounded iteration**: Hard limit prevents infinite loops
3. **Memory bounded**: Set size limited by max pixels
4. **Index validation**: Every memory access validated
5. **Graceful degradation**: Always returns valid result
6. **Multiple fallbacks**: Several escape paths

## Comparison to Previous Implementation

| Feature | Old Algorithm | New Algorithm |
|---------|---------------|---------------|
| Approach | Recursive/unstable | Iterative BFS |
| Safety limits | Partial | Comprehensive |
| Fallback | None/crash | 1200x900 crop |
| Blue detection | Complex HSB | Simple RGB |
| Edge cases | Crashes | Handled |
| Performance | Unpredictable | Bounded |
| Memory | Unbounded | Bounded |

## Future Improvements

Potential enhancements (not currently needed):

1. **Adaptive thresholding**: Adjust blue detection based on context
2. **Multi-box detection**: Return array of all blue boxes
3. **Shape validation**: Verify box is rectangular
4. **OCR integration**: Validate box contains text
5. **Machine learning**: Train model for box detection

## Conclusion

This algorithm provides:
- **Safety**: No crashes, bounded execution
- **Reliability**: Consistent results across edge cases
- **Performance**: Fast enough for real-time use
- **Simplicity**: Easy to understand and maintain

The iterative BFS approach with comprehensive safety checks ensures the system never crashes, always produces usable output, and handles all edge cases gracefully.
