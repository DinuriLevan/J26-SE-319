# Stage 4 dev study: localisation on spliced errors (DEV children only)

- spliced_attempts: 180
- detection: 0.756
- loc_top1: 0.743
- loc_any: 0.934
- clean_attempts: 78
- clean_accept: 0.923

## By language (detected attempts)

| language   |     top1 |      any |
|:-----------|---------:|---------:|
| en         | 0.652778 | 0.902778 |
| si         | 0.84375  | 0.96875  |

## By word

| word   |     top1 |      any |   detection |
|:-------|---------:|---------:|------------:|
| w_001  | 0.833333 | 0.944444 |       0.9   |
| w_002  | 0.833333 | 1        |       0.643 |
| w_003  | 0.785714 | 0.928571 |       0.875 |
| w_004  | 0.928571 | 1        |       0.875 |
| w_005  | 0.454545 | 0.818182 |       0.458 |
| w_006  | 0.8      | 1        |       0.667 |
| w_007  | 0.592593 | 0.814815 |       0.964 |
| w_008  | 0.714286 | 1        |       0.778 |

## Error types assigned to the worst flagged unit

| error_type   |   count |
|:-------------|--------:|
| distortion   |     120 |
| substitution |      16 |
