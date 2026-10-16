# Stage 4 dev study: localisation on spliced errors (DEV children only)

- spliced_attempts: 180
- detection: 0.578
- loc_top1: 0.740
- loc_any: 0.904
- clean_attempts: 78
- clean_accept: 0.936

## By language (detected attempts)

| language   |    top1 |     any |
|:-----------|--------:|--------:|
| en         | 0.575   | 0.8     |
| si         | 0.84375 | 0.96875 |

## By word

| word   |     top1 |      any |   detection |
|:-------|---------:|---------:|------------:|
| w_001  | 0.833333 | 0.944444 |       0.9   |
| w_002  | 0.833333 | 1        |       0.643 |
| w_003  | 0.785714 | 0.928571 |       0.875 |
| w_004  | 0.928571 | 1        |       0.875 |
| w_005  | 0.5625   | 0.75     |       0.667 |
| w_007  | 0.375    | 0.75     |       0.286 |
| w_008  | 0.6875   | 0.875    |       0.889 |

## Error types assigned to the worst flagged unit

| error_type   |   count |
|:-------------|--------:|
| distortion   |      86 |
| substitution |      18 |
