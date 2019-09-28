# MultiFR_optimisation
Joint market clearing of energy and frequency services, including a pricing methodology.

Frequency services include:
 - **Inertia**.
 - Different types of **Frequency Response (FR)**, allowing to consider any combination of FR dynamics.
 - An **optimised largest-loss** (the code considers the N-1 reliability requirement for scheduling frequency services).

The code is self-explanatory. For further explanation, refer to [this paper](
http://arxiv.org/abs/1909.06671).

The optimisation problem is solved via the toolbox **YALMIP**, you can find instructions for how to install it [here](https://yalmip.github.io/tutorial/installation/). You will also need to install some external MISOCP solver like Mosek or Gurobi, both of which have academic licenses available. Remember to also install the Matlab functionalities of that solver.

YALMIP is very easy to use. Once installed, you can learn how to use it with file "simple_EconomicDispatch_YALMIP.m", contained in this repository, and through the documentation available in YALMIP's website.

This code has been tested with MATLAB version 2017b.
