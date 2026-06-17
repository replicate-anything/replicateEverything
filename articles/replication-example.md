# Replication Examples Using Code

``` r

library(replicateEverything)
```

### System Architecture

This is the system architecture on which this package is built. There is
a registry that host all the repositories for past studies. Then, the
`replicateEverything` package interact with the repositories and then
works the magic.

## Run single replication

``` r

run_replication(
  "10.1177/00491241211036161",
  "fig_1"
)
```

    ##                          L         H  rho  tau          label
    ## simple           0.3333333 1.0000000 -0.5  0.1         simple
    ## unobserved       0.3333333 0.3333333 -0.5  0.1     unobserved
    ## monotone         0.3333333 0.3333333 -0.5  0.1       monotone
    ## two_step_homog   0.4562255 1.0000000 -0.5  0.1 two_step_homog
    ## inifinte_homog   0.1405457 1.0000000 -0.5  0.1 inifinte_homog
    ## best_lower       0.8000000 0.8000000 -0.5  0.1     best_lower
    ## best_cov_un      1.0000000 1.0000000 -0.5  0.1    best_cov_un
    ## best_cov_ob      1.0000000 1.0000000 -0.5  0.1    best_cov_ob
    ## simple1          0.6666667 1.0000000 -0.5 0.25         simple
    ## unobserved1      0.6666667 0.6666667 -0.5 0.25     unobserved
    ## monotone1        0.6666667 0.6666667 -0.5 0.25       monotone
    ## two_step_homog1  0.7346939 1.0000000 -0.5 0.25 two_step_homog
    ## inifinte_homog1  0.1666667 1.0000000 -0.5 0.25 inifinte_homog
    ## best_lower1      0.8750000 0.8750000 -0.5 0.25     best_lower
    ## best_cov_un1     1.0000000 1.0000000 -0.5 0.25    best_cov_un
    ## best_cov_ob1     1.0000000 1.0000000 -0.5 0.25    best_cov_ob
    ## simple2          0.1818182 1.0000000    0  0.1         simple
    ## unobserved2      0.1818182 0.1818182    0  0.1     unobserved
    ## monotone2        0.1818182 0.1818182    0  0.1       monotone
    ## two_step_homog2  0.2308862 1.0000000    0  0.1 two_step_homog
    ## inifinte_homog2  0.3162278 1.0000000    0  0.1 inifinte_homog
    ## best_lower2      0.5500000 0.5500000    0  0.1     best_lower
    ## best_cov_un2     1.0000000 1.0000000    0  0.1    best_cov_un
    ## best_cov_ob2     1.0000000 1.0000000    0  0.1    best_cov_ob
    ## simple11         0.4000000 1.0000000    0 0.25         simple
    ## unobserved11     0.4000000 0.4000000    0 0.25     unobserved
    ## monotone11       0.4000000 0.4000000    0 0.25       monotone
    ## two_step_homog11 0.4444444 1.0000000    0 0.25 two_step_homog
    ## inifinte_homog11 0.5000000 1.0000000    0 0.25 inifinte_homog
    ## best_lower11     0.6250000 0.6250000    0 0.25     best_lower
    ## best_cov_un11    1.0000000 1.0000000    0 0.25    best_cov_un
    ## best_cov_ob11    1.0000000 1.0000000    0 0.25    best_cov_ob
    ## simple3          0.1250000 0.3750000  0.5  0.1         simple
    ## unobserved3      0.1250000 0.1250000  0.5  0.1     unobserved
    ## monotone3        0.1250000 0.1250000  0.5  0.1       monotone
    ## two_step_homog3  0.1390453 0.3047733  0.5  0.1 two_step_homog
    ## inifinte_homog3  0.4919099 0.2782559  0.5  0.1 inifinte_homog
    ## best_lower3      0.3000000 0.3000000  0.5  0.1     best_lower
    ## best_cov_un3     0.3750000 0.3750000  0.5  0.1    best_cov_un
    ## best_cov_ob3     1.0000000 1.0000000  0.5  0.1    best_cov_ob
    ## simple12         0.2857143 0.4285714  0.5 0.25         simple
    ## unobserved12     0.2857143 0.2857143  0.5 0.25     unobserved
    ## monotone12       0.2857143 0.2857143  0.5 0.25       monotone
    ## two_step_homog12 0.2975207 0.4049587  0.5 0.25 two_step_homog
    ## inifinte_homog12 0.8333333 0.3968503  0.5 0.25 inifinte_homog
    ## best_lower12     0.3750000 0.3750000  0.5 0.25     best_lower
    ## best_cov_un12    0.4285714 0.4285714  0.5 0.25    best_cov_un
    ## best_cov_ob12    1.0000000 1.0000000  0.5 0.25    best_cov_ob
    ##                                        names
    ## simple                         Simple bounds
    ## unobserved              Unobserved mediators
    ## monotone                           Monotonic
    ## two_step_homog          Two step homogeneous
    ## inifinte_homog     Infinite step homogeneous
    ## best_lower          Best (positive) mediator
    ## best_cov_un      Best (unobserved) covariate
    ## best_cov_ob        Best (observed) covariate
    ## simple1                        Simple bounds
    ## unobserved1             Unobserved mediators
    ## monotone1                          Monotonic
    ## two_step_homog1         Two step homogeneous
    ## inifinte_homog1    Infinite step homogeneous
    ## best_lower1         Best (positive) mediator
    ## best_cov_un1     Best (unobserved) covariate
    ## best_cov_ob1       Best (observed) covariate
    ## simple2                        Simple bounds
    ## unobserved2             Unobserved mediators
    ## monotone2                          Monotonic
    ## two_step_homog2         Two step homogeneous
    ## inifinte_homog2    Infinite step homogeneous
    ## best_lower2         Best (positive) mediator
    ## best_cov_un2     Best (unobserved) covariate
    ## best_cov_ob2       Best (observed) covariate
    ## simple11                       Simple bounds
    ## unobserved11            Unobserved mediators
    ## monotone11                         Monotonic
    ## two_step_homog11        Two step homogeneous
    ## inifinte_homog11   Infinite step homogeneous
    ## best_lower11        Best (positive) mediator
    ## best_cov_un11    Best (unobserved) covariate
    ## best_cov_ob11      Best (observed) covariate
    ## simple3                        Simple bounds
    ## unobserved3             Unobserved mediators
    ## monotone3                          Monotonic
    ## two_step_homog3         Two step homogeneous
    ## inifinte_homog3    Infinite step homogeneous
    ## best_lower3         Best (positive) mediator
    ## best_cov_un3     Best (unobserved) covariate
    ## best_cov_ob3       Best (observed) covariate
    ## simple12                       Simple bounds
    ## unobserved12            Unobserved mediators
    ## monotone12                         Monotonic
    ## two_step_homog12        Two step homogeneous
    ## inifinte_homog12   Infinite step homogeneous
    ## best_lower12        Best (positive) mediator
    ## best_cov_un12    Best (unobserved) covariate
    ## best_cov_ob12      Best (observed) covariate

## Replicate an entire paper

``` r

replicate_paper("10.1177/00491241211036161")
```

    ## Replicating: Bounding Causes of Effects With Mediators

    ## 

    ## Running: fig_1
