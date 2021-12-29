from fenics import *
import cfd_gym

# Print log messages only from the root process in parallel
parameters["std_out_all_processes"] = False;

#cfd_gym.utils.mesh.convert_to_xdmf('mesh/cyl.msh', out_dir='mesh', dim=2)
mesh, mf = cfd_gym.utils.mesh.load_mesh('mesh')

T = 300.0            # final time
dt = 1e-2           # time step size
num_steps = int(T//dt)  # number of time steps
mu = 1/100         # dynamic viscosity
rho = 1            # density
U_inf = Constant((1.0, 0))

# Define function spaces
V = VectorFunctionSpace(mesh, 'CG', 2)  # Velocity
Q = FunctionSpace(mesh, 'CG', 1)        # Pressure

# Define boundaries
inflow   = 'near(x[0], -60)'
outflow  = 'near(x[0], 200)'
walls    = 'near(x[1], -20) || near(x[1], 20)'
cylinder = 'on_boundary && x[0]>-0.6 && x[0]<0.6 && x[1]>-0.6 && x[1]<0.6'

# Define boundary conditions
bcu_inflow = DirichletBC(V, U_inf, inflow)
bcu_walls = DirichletBC(V, U_inf, walls)
bcu_cylinder = DirichletBC(V, Constant((0, 0)), cylinder)
bcp_outflow = DirichletBC(Q, Constant(0), outflow)
bcu = [bcu_inflow, bcu_walls, bcu_cylinder]
bcp = [bcp_outflow]

# Define trial and test functions
u = TrialFunction(V)
v = TestFunction(V)
p = TrialFunction(Q)
q = TestFunction(Q)

# Define functions for solutions at previous and current time steps
u_n = Function(V)
u_  = Function(V)
p_n = Function(Q)
p_  = Function(Q)

# Define expressions used in variational forms
U  = 0.5*(u_n + u)
n  = FacetNormal(mesh)
f  = Constant((0, 0))
k  = Constant(dt)
mu = Constant(mu)
rho = Constant(rho)

# Define symmetric gradient
def epsilon(u):
    return sym(nabla_grad(u))

# Define stress tensor
def sigma(u, p):
    return 2*mu*epsilon(u) - p*Identity(len(u))

# Define variational problem for step 1
F1 = rho*dot((u - u_n) / k, v)*dx \
   + rho*dot(dot(u_n, nabla_grad(u_n)), v)*dx \
   + inner(sigma(U, p_n), epsilon(v))*dx \
   + dot(p_n*n, v)*ds - dot(mu*nabla_grad(U)*n, v)*ds \
   - dot(f, v)*dx
a1 = lhs(F1)
L1 = rhs(F1)

# Define variational problem for step 2
a2 = dot(nabla_grad(p), nabla_grad(q))*dx
L2 = dot(nabla_grad(p_n), nabla_grad(q))*dx - (1/k)*div(u_)*q*dx

# Define variational problem for step 3
a3 = dot(u, v)*dx
L3 = dot(u_, v)*dx - k*dot(nabla_grad(p_ - p_n), v)*dx

# Assemble matrices
A1 = assemble(a1)
A2 = assemble(a2)
A3 = assemble(a3)

# Apply boundary conditions to matrices
[bc.apply(A1) for bc in bcu]
[bc.apply(A2) for bc in bcp]

# # Create XDMF files for visualization output
# xdmffile_u = XDMFFile(MPI.comm_world, 'output/velocity.xdmf')
# xdmffile_p = XDMFFile(MPI.comm_world, 'output/pressure.xdmf')

outfile_u = File(f"output/velocity.pvd")
outfile_p = File(f"output/pressure.pvd")
u_.rename("u", "velocity")
p_.rename("p", "pressure")

# Time-stepping
t = 0
for n in range(num_steps):
    # Update current time
    t += dt

    # Step 1: Tentative velocity step
    b1 = assemble(L1)
    [bc.apply(b1) for bc in bcu]
    solve(A1, u_.vector(), b1, 'bicgstab', 'hypre_amg')

    # Step 2: Pressure correction step
    b2 = assemble(L2)
    [bc.apply(b2) for bc in bcp]
    solve(A2, p_.vector(), b2, 'bicgstab', 'hypre_amg')

    # Step 3: Velocity correction step
    b3 = assemble(L3)
    solve(A3, u_.vector(), b3, 'cg', 'sor')

#     # Save solution to file (XDMF/HDF5)
#     xdmffile_u.write(u_, t)
#     xdmffile_p.write(p_, t)
    if n % 10 == 0:
        outfile_u << u_
        outfile_p << p_

    # Update previous solution
    u_n.assign(u_)
    p_n.assign(p_)

    # Simple convergence check
    if(MPI.rank(MPI.comm_world) == 0):
        print(f't: {t:0.03f}\t u max: {u_.vector()[:].max()}', flush=True)