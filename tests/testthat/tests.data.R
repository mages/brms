test_that("Test that brm.data returns correct data names for fixed and random effects", {
  expect_equal(names(brm.data(rating ~ treat + period + carry + (1|subject), data = inhaler)),
               c("N","Y","K","X","subject","N_subject","K_subject","Z_subject","NC_subject"))
  expect_equal(names(brm.data(rating ~ treat + period + carry + (1+treat|subject), data = inhaler,
               family = "categorical")),
               c("N","Y","Kp","Xp","subject","N_subject","K_subject","Z_subject","NC_subject","max_obs"))
  expect_equal(names(brm.data(y ~ x + (1|g) + (1|h), family = "poisson",
              data = data.frame(y = 1:10, g = 1:10, h = 11:10, x = rep(0,10)))),
               c("N","Y","K","X","g","N_g","K_g","Z_g","NC_g","h","N_h","K_h","Z_h","NC_h"))
})

test_that("Test that brm.data returns correct data names for addition and partial variables", {
  data <- data.frame(y = 1:10, w = 1:10, t = 1:10, x = rep(0,10), c = sample(-1:1,10,TRUE))
  expect_equal(names(brm.data(y | se(w) ~ x, family = "gaussian", data = data)), 
               c("N","Y","K","X","sigma"))
  expect_equal(names(brm.data(y | weights(w) ~ x, family = "gaussian", data = data)), 
               c("N","Y","K","X","weights"))
  expect_equal(names(brm.data(y | cens(c) ~ x, family = "cauchy", data = data)), 
               c("N","Y","K","X","cens"))
  expect_equal(names(brm.data(y | trials(t) ~ x, family = "binomial", data = data)), 
               c("N","Y","K","X","max_obs"))
  expect_equal(names(brm.data(y | trials(10) ~ x, family = "binomial", data = data)), 
               c("N","Y","K","X","max_obs"))
  expect_equal(names(brm.data(y | cat(t) ~ x, family = "acat", data = data)), 
               c("N","Y","K","X","max_obs"))
  expect_equal(names(brm.data(y | cat(10) ~ x, family = "cumulative", data = data)), 
               c("N","Y","K","X","max_obs"))
})

test_that("Test that brm.data accepts correct response variables depending on the family", {
  expect_equal(brm.data(y ~ 1, data = data.frame(y = seq(-9.9,0,0.1)), family = "student")$Y, seq(-9.9,0,0.1))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = 1:10), family = "binomial")$Y, 1:10)
  expect_equal(brm.data(y ~ 1, data = data.frame(y = 10:20), family = "poisson")$Y, 10:20)
  expect_equal(brm.data(y ~ 1, data = data.frame(y = rep(-c(1:2),5)), family = "bernoulli")$Y, rep(1:0,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = rep(c(TRUE, FALSE),5)), family = "bernoulli")$Y, rep(1:0,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = rep(1:10,5)), family = "categorical")$Y, rep(1:10,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = rep(-4:5,5)), family = "categorical")$Y, rep(1:10,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = factor(rep(-4:5,5))), family = "categorical")$Y, rep(1:10,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = rep(1:10,5)), family = "cumulative")$Y, rep(1:10,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = factor(rep(-4:5,5), order = TRUE)), family = "acat")$Y, 
               rep(1:10,5))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = seq(0,10,0.1)), family = "exponential")$Y, seq(0,10,0.1))
  expect_equal(brm.data(cbind(y1,y2) | weights(w) ~ x, family = "gaussian",
               data = data.frame(y1 = 1:10, y2 = 11:20, w = 1:10, x = rep(0,10)))$Y, cbind(1:10,11:20))
})

test_that("Test that brm.data rejects incorrect response variables depending on the family", {
  expect_error(brm.data(y ~ 1, data = data.frame(y = factor(1:10)), family = "cauchy"),
               "family cauchy expects numeric response variable")
  expect_error(brm.data(y ~ 1, data = data.frame(y = -5:5), family = "geometric"),
               "family geometric expects response variable of non-negative integers")
  expect_error(brm.data(y ~ 1, data = data.frame(y = -1:1), family = "bernoulli"),
               "family bernoulli expects response variable to contain only two different values")
  expect_error(brm.data(y ~ 1, data = data.frame(y = factor(-1:1)), family = "cratio"),
               "family cratio requires factored response variables to be ordered")
  expect_error(brm.data(y ~ 1, data = data.frame(y = rep(0.5:7.5), 2), family = "sratio"),
               "family sratio expects either integers or ordered factors as response variables")
  expect_error(brm.data(y ~ 1, data = data.frame(y = rep(-7.5:7.5), 2), family = "gamma"),
               "family gamma requires response variable to be non-negative")
})

test_that("Test that brm.data suggests using family bernoulli if appropriate", {
  expect_message(brm.data(y ~ 1, data = data.frame(y = rep(0:1,5)), family = "binomial"),
                 "Only 2 levels detected so that family 'bernoulli' might be a more efficient choice.")
  expect_message(brm.data(y ~ 1, data = data.frame(y = rep(0:1,5)), family = "categorical"),
                 "Only 2 levels detected so that family 'bernoulli' might be a more efficient choice.")
})

test_that("Test that brm.data returns correct values for addition arguments", {
  expect_equal(brm.data(y | se(c) ~ 1, data = data.frame(y = rnorm(9), c = 1:9))$sigma, 1:9)
  expect_equal(brm.data(y | weights(c) ~ 1, data = data.frame(y = rnorm(9), c = 1:9))$weights, 1:9)
  expect_equal(brm.data(y | cens(c) ~ 1, data = data.frame(y = rnorm(9), c = rep(-1:1,3)))$cens, rep(-1:1,3))
  expect_equal(brm.data(y | cens(c) ~ 1, data = data.frame(y = rnorm(9), c = rep(c("left","none","right"),3)))$cens,
               rep(-1:1,3))
  expect_equal(brm.data(y | cens(c) ~ 1, data = data.frame(y = rnorm(8), c = rep(c(T,F),4)))$cens, rep(1:0,4))
  expect_equal(brm.data(y ~ 1, data = data.frame(y = 1:9), family = "binomial")$max_obs, 9)
  expect_equal(brm.data(y | trials(10) ~ 1, data = data.frame(y = 1:9), family = "binomial")$max_obs, 10)
  expect_equal(brm.data(y | trials(c) ~ 1, data = data.frame(y = 1:9, c = 11:19), 
                        family = "binomial")$max_obs, 11:19)
  expect_equal(brm.data(y | cat(c) ~ 1, data = data.frame(y = 1:9, c = 11:19), 
                        family = "categorical")$max_obs, 11:19)
})

test_that("Test that brm.data rejects incorrect addition arguments", {
  expect_error(brm.data(y | se(c) ~ 1, data = data.frame(y = rnorm(9), c = -c(1:9))), 
               "standard errors must be non-negative")
  expect_error(brm.data(y | weights(c) ~ 1, data = data.frame(y = rnorm(9), c = -c(1:9))), 
               "weights must be non-negative")
  expect_error(brm.data(y | cens(c) ~ 1, data = data.frame(y = rnorm(9), c = rep(-2:1,3))))
  expect_error(brm.data(y | trials(c) ~ 1, data = data.frame(y = 1:10, c = 10:1), family = "binomial"),
               "The number of trials / categories is smaller the response variable would suggest.")
})

test_that("Test that brm.data handles addition arguments and autocorrelation in multinormal models", {
  data <- data.frame(y1=1:10, y2=11:20, w=1:10, x=rep(0,10), tim=10:1, g = rep(1:2,5))
  expect_equal(brm.data(cbind(y1,y2) | weights(w) ~ x, family = "gaussian", data = data)$weights, 1:10)
  expect_equal(brm.data(cbind(y1,y2) | weights(w) ~ x, family = "gaussian", 
                        autocor = cor.ar(~tim|g:trait), data = data)$Y,
               cbind(c(seq(9,1,-2), seq(10,2,-2)), c(seq(19,11,-2), seq(20,12,-2))))
  expect_error(brm.data(cbind(y1,y2) | weights(w) ~ x, family = "gaussian", 
                        autocor = cor.ar(~tim|g), data = data),
               "autocorrelation structures for multiple responses must contain 'trait' as grouping variable")
  expect_error(brm.data(cbind(y1,y2) | weights(w) ~ x, family = "multigaussian", 
                        autocor = cor.ar(~tim|g), data = data),
               "family 'multigaussian' is depricated. Use family 'gaussian' instead")
})

test_that("Test that brm.data returns correct data for autocorrelations structures", {
  data <- data.frame(y=1:10, x=rep(0,10), tim=10:1, g = rep(3:4,5))
  expect_equal(brm.data(y ~ x, family = "gaussian", autocor = cor.ar(~tim|g), data = data)$Yar,
               cbind(c(0,3.5,1.5,-0.5,-2.5,0,4.5,2.5,0.5,-1.5)))
  expect_equal(brm.data(y ~ x, family = "gaussian", autocor = cor.ar(~tim|g, p = 2), data = data)$Yar,
               cbind(c(0,3.5,1.5,-0.5,-2.5,0,4.5,2.5,0.5,-1.5), c(0,0,3.5,1.5,-0.5,0,0,4.5,2.5,0.5)))
  expect_equal(brm.data(y ~ x, family = "gaussian", autocor = cor.ma(~tim|g), data = data)$tgroup,
               c(rep(1,5), rep(2,5)))
})

test_that("Test that melt returns data in correct long format", {
  data <- data.frame(x = rep(c("a","b"), 5), y1 = 1:10, y2 = 11:20, y3 = 21:30, z = 100:91)
  expect_equal(melt(data, response = "y1", family = "poisson"), data)
  
  target1 <- data.frame(x = rep(c("a","b"), 10), y2 = rep(11:20, 2), z = rep(100:91, 2),
                        trait = c(rep("y3", 10), rep("y1", 10)), y3 = c(21:30,1:10))
  expect_equal(melt(data, response = c("y3", "y1"), family = "gaussian"), target1)
  
  target2 <- data.frame(x = rep(c("a","b"), 15), z = rep(100:91, 3),
                        trait = c(rep("y2", 10), rep("y1", 10), rep("y3", 10)), 
                        y2 = c(11:20, 1:10, 21:30))
  expect_equal(melt(data, response = c("y2", "y1", "y3"), family = "gaussian"), target2)
})