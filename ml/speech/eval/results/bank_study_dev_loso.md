# Stage 3 dev study: multi-reference bank vs single reference

- Dev speakers: ['g3_s1', 'g3_s3', 'g4_s1', 'g4_s2']; 922 query tokens; 7702 trials (922 correct, 6780 wrong)
- Leave-one-out unit: speaker
- k = 3, n_std = 2.0, min_refs = 4; config fallback = 0.245
- Trials in the bank regime (>= 4 refs): 1108 (14%); learned thresholds: median 0.220, range 0.146-0.337
- **Dev-best global threshold for a single reference: 0.245** (recommended fallback_threshold)

## Balanced accuracy (all languages)

|                                          |   bank_learned |   single_devbest |   single_fallback |
|:-----------------------------------------|---------------:|-----------------:|------------------:|
| ('all', 'near_miss')                     |          0.841 |            0.828 |             0.828 |
| ('all', 'random')                        |          0.941 |            0.94  |             0.94  |
| ('bank regime (>= 4 refs)', 'near_miss') |          0.861 |            0.858 |             0.858 |
| ('bank regime (>= 4 refs)', 'random')    |          0.938 |            0.964 |             0.964 |

## Full table

| subset                  | negatives   | language   | system          |   balanced_accuracy |   accept_correct |   reject_wrong |   n_correct |   n_wrong |
|:------------------------|:------------|:-----------|:----------------|--------------------:|-----------------:|---------------:|------------:|----------:|
| all                     | random      | all        | single_fallback |               0.94  |            0.895 |          0.985 |         922 |      4610 |
| all                     | random      | all        | single_devbest  |               0.94  |            0.895 |          0.985 |         922 |      4610 |
| all                     | random      | all        | bank_learned    |               0.941 |            0.897 |          0.985 |         922 |      4610 |
| all                     | random      | en         | single_fallback |               0.933 |            0.88  |          0.985 |         384 |      1920 |
| all                     | random      | en         | single_devbest  |               0.933 |            0.88  |          0.985 |         384 |      1920 |
| all                     | random      | en         | bank_learned    |               0.938 |            0.891 |          0.985 |         384 |      1920 |
| all                     | random      | si         | single_fallback |               0.945 |            0.905 |          0.986 |         538 |      2690 |
| all                     | random      | si         | single_devbest  |               0.945 |            0.905 |          0.986 |         538 |      2690 |
| all                     | random      | si         | bank_learned    |               0.943 |            0.901 |          0.985 |         538 |      2690 |
| all                     | near_miss   | all        | single_fallback |               0.828 |            0.895 |          0.761 |         922 |      2170 |
| all                     | near_miss   | all        | single_devbest  |               0.828 |            0.895 |          0.761 |         922 |      2170 |
| all                     | near_miss   | all        | bank_learned    |               0.841 |            0.897 |          0.786 |         922 |      2170 |
| all                     | near_miss   | en         | single_fallback |               0.819 |            0.88  |          0.757 |         384 |       791 |
| all                     | near_miss   | en         | single_devbest  |               0.819 |            0.88  |          0.759 |         384 |       791 |
| all                     | near_miss   | en         | bank_learned    |               0.835 |            0.891 |          0.779 |         384 |       791 |
| all                     | near_miss   | si         | single_fallback |               0.834 |            0.905 |          0.763 |         538 |      1379 |
| all                     | near_miss   | si         | single_devbest  |               0.834 |            0.905 |          0.763 |         538 |      1379 |
| all                     | near_miss   | si         | bank_learned    |               0.846 |            0.901 |          0.79  |         538 |      1379 |
| bank regime (>= 4 refs) | random      | all        | single_fallback |               0.964 |            0.943 |          0.986 |         158 |       567 |
| bank regime (>= 4 refs) | random      | all        | single_devbest  |               0.964 |            0.943 |          0.986 |         158 |       567 |
| bank regime (>= 4 refs) | random      | all        | bank_learned    |               0.938 |            0.899 |          0.977 |         158 |       567 |
| bank regime (>= 4 refs) | random      | en         | single_fallback |               0.966 |            0.939 |          0.993 |          98 |       295 |
| bank regime (>= 4 refs) | random      | en         | single_devbest  |               0.966 |            0.939 |          0.993 |          98 |       295 |
| bank regime (>= 4 refs) | random      | en         | bank_learned    |               0.957 |            0.918 |          0.997 |          98 |       295 |
| bank regime (>= 4 refs) | random      | si         | single_fallback |               0.964 |            0.95  |          0.978 |          60 |       272 |
| bank regime (>= 4 refs) | random      | si         | single_devbest  |               0.964 |            0.95  |          0.978 |          60 |       272 |
| bank regime (>= 4 refs) | random      | si         | bank_learned    |               0.911 |            0.867 |          0.956 |          60 |       272 |
| bank regime (>= 4 refs) | near_miss   | all        | single_fallback |               0.858 |            0.943 |          0.773 |         158 |       383 |
| bank regime (>= 4 refs) | near_miss   | all        | single_devbest  |               0.858 |            0.943 |          0.773 |         158 |       383 |
| bank regime (>= 4 refs) | near_miss   | all        | bank_learned    |               0.861 |            0.899 |          0.822 |         158 |       383 |
| bank regime (>= 4 refs) | near_miss   | en         | single_fallback |               0.875 |            0.939 |          0.811 |          98 |       206 |
| bank regime (>= 4 refs) | near_miss   | en         | single_devbest  |               0.875 |            0.939 |          0.811 |          98 |       206 |
| bank regime (>= 4 refs) | near_miss   | en         | bank_learned    |               0.899 |            0.918 |          0.879 |          98 |       206 |
| bank regime (>= 4 refs) | near_miss   | si         | single_fallback |               0.839 |            0.95  |          0.729 |          60 |       177 |
| bank regime (>= 4 refs) | near_miss   | si         | single_devbest  |               0.839 |            0.95  |          0.729 |          60 |       177 |
| bank regime (>= 4 refs) | near_miss   | si         | bank_learned    |               0.812 |            0.867 |          0.757 |          60 |       177 |
