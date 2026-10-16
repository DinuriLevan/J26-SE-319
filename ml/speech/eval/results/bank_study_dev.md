# Stage 3 dev study: multi-reference bank vs single reference

- Dev speakers: ['g3_s1', 'g3_s3', 'g4_s1', 'g4_s2']; 922 query tokens; 7702 trials (922 correct, 6780 wrong)
- Leave-one-out unit: token
- k = 3, n_std = 2.0, min_refs = 4; config fallback = 0.245
- Trials in the bank regime (>= 4 refs): 1108 (14%); learned thresholds: median 0.196, range 0.120-0.315
- **Dev-best global threshold for a single reference: 0.245** (recommended fallback_threshold)

## Balanced accuracy (all languages)

|                                          |   bank_learned |   single_devbest |   single_fallback |
|:-----------------------------------------|---------------:|-----------------:|------------------:|
| ('all', 'near_miss')                     |          0.841 |            0.828 |             0.828 |
| ('all', 'random')                        |          0.932 |            0.94  |             0.94  |
| ('bank regime (>= 4 refs)', 'near_miss') |          0.855 |            0.858 |             0.858 |
| ('bank regime (>= 4 refs)', 'random')    |          0.887 |            0.964 |             0.964 |

## Full table

| subset                  | negatives   | language   | system          |   balanced_accuracy |   accept_correct |   reject_wrong |   n_correct |   n_wrong |
|:------------------------|:------------|:-----------|:----------------|--------------------:|-----------------:|---------------:|------------:|----------:|
| all                     | random      | all        | single_fallback |               0.94  |            0.895 |          0.985 |         922 |      4610 |
| all                     | random      | all        | single_devbest  |               0.94  |            0.895 |          0.985 |         922 |      4610 |
| all                     | random      | all        | bank_learned    |               0.932 |            0.876 |          0.987 |         922 |      4610 |
| all                     | random      | en         | single_fallback |               0.933 |            0.88  |          0.985 |         384 |      1920 |
| all                     | random      | en         | single_devbest  |               0.933 |            0.88  |          0.985 |         384 |      1920 |
| all                     | random      | en         | bank_learned    |               0.92  |            0.854 |          0.986 |         384 |      1920 |
| all                     | random      | si         | single_fallback |               0.945 |            0.905 |          0.986 |         538 |      2690 |
| all                     | random      | si         | single_devbest  |               0.945 |            0.905 |          0.986 |         538 |      2690 |
| all                     | random      | si         | bank_learned    |               0.94  |            0.892 |          0.988 |         538 |      2690 |
| all                     | near_miss   | all        | single_fallback |               0.828 |            0.895 |          0.761 |         922 |      2170 |
| all                     | near_miss   | all        | single_devbest  |               0.828 |            0.895 |          0.761 |         922 |      2170 |
| all                     | near_miss   | all        | bank_learned    |               0.841 |            0.876 |          0.805 |         922 |      2170 |
| all                     | near_miss   | en         | single_fallback |               0.819 |            0.88  |          0.757 |         384 |       791 |
| all                     | near_miss   | en         | single_devbest  |               0.819 |            0.88  |          0.759 |         384 |       791 |
| all                     | near_miss   | en         | bank_learned    |               0.83  |            0.854 |          0.805 |         384 |       791 |
| all                     | near_miss   | si         | single_fallback |               0.834 |            0.905 |          0.763 |         538 |      1379 |
| all                     | near_miss   | si         | single_devbest  |               0.834 |            0.905 |          0.763 |         538 |      1379 |
| all                     | near_miss   | si         | bank_learned    |               0.849 |            0.892 |          0.805 |         538 |      1379 |
| bank regime (>= 4 refs) | random      | all        | single_fallback |               0.964 |            0.943 |          0.986 |         158 |       567 |
| bank regime (>= 4 refs) | random      | all        | single_devbest  |               0.964 |            0.943 |          0.986 |         158 |       567 |
| bank regime (>= 4 refs) | random      | all        | bank_learned    |               0.887 |            0.778 |          0.995 |         158 |       567 |
| bank regime (>= 4 refs) | random      | en         | single_fallback |               0.966 |            0.939 |          0.993 |          98 |       295 |
| bank regime (>= 4 refs) | random      | en         | single_devbest  |               0.966 |            0.939 |          0.993 |          98 |       295 |
| bank regime (>= 4 refs) | random      | en         | bank_learned    |               0.888 |            0.776 |          1     |          98 |       295 |
| bank regime (>= 4 refs) | random      | si         | single_fallback |               0.964 |            0.95  |          0.978 |          60 |       272 |
| bank regime (>= 4 refs) | random      | si         | single_devbest  |               0.964 |            0.95  |          0.978 |          60 |       272 |
| bank regime (>= 4 refs) | random      | si         | bank_learned    |               0.886 |            0.783 |          0.989 |          60 |       272 |
| bank regime (>= 4 refs) | near_miss   | all        | single_fallback |               0.858 |            0.943 |          0.773 |         158 |       383 |
| bank regime (>= 4 refs) | near_miss   | all        | single_devbest  |               0.858 |            0.943 |          0.773 |         158 |       383 |
| bank regime (>= 4 refs) | near_miss   | all        | bank_learned    |               0.855 |            0.778 |          0.932 |         158 |       383 |
| bank regime (>= 4 refs) | near_miss   | en         | single_fallback |               0.875 |            0.939 |          0.811 |          98 |       206 |
| bank regime (>= 4 refs) | near_miss   | en         | single_devbest  |               0.875 |            0.939 |          0.811 |          98 |       206 |
| bank regime (>= 4 refs) | near_miss   | en         | bank_learned    |               0.878 |            0.776 |          0.981 |          98 |       206 |
| bank regime (>= 4 refs) | near_miss   | si         | single_fallback |               0.839 |            0.95  |          0.729 |          60 |       177 |
| bank regime (>= 4 refs) | near_miss   | si         | single_devbest  |               0.839 |            0.95  |          0.729 |          60 |       177 |
| bank regime (>= 4 refs) | near_miss   | si         | bank_learned    |               0.83  |            0.783 |          0.876 |          60 |       177 |
