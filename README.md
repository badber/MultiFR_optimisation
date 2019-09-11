# MultiFR_optimisation
Joint market clearing of energy and frequency services, including a pricing methodology.

Frequency services include:
 - **Inertia**.
 - Different types of **Frequency Response (FR)**, allowing to consider any combination of FR dynamics and activation delays.
 - A **reduced largest-loss** (the code considers the N-1 reliability requirement for scheduling frequency services).

The code is self-explanatory. For further explanation, refer to this paper.

The optimisation problem is solved via the toolbox **YALMIP**, you can find instructions on how to install it [here](https://yalmip.github.io/tutorial/installation/). You will also need to install some external MISOCP solver like Mosek or Gurobi, both of which have academic licenses available. Remember to also install the Matlab functionalities of that solver.
