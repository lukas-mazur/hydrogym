import firedrake as fd
from firedrake.petsc import PETSc
from ufl import curl
import numpy as np

import hydrogym as gym

output_dir = 'controlled'
pvd_out = f"{output_dir}/solution.pvd"
checkpoint = f"output/checkpoint.h5"

cyl = gym.flows.Cylinder()
cyl.load_checkpoint(checkpoint)  # Reload previous solution

# Time step
dt = 1e-2
Tf = 100.0

vort = fd.Function(cyl.pressure_space, name='vort')
def compute_vort(state):
    u, p = state
    vort.assign(fd.project(curl(u), cyl.pressure_space))
    return (u, p, vort)

data = np.array([0, 0, 0], ndmin=2)
def forces(iter, t, state):
    global data
    u, p = state
    CL, CD = cyl.compute_forces(u, p)
    if fd.COMM_WORLD.rank == 0:
        data = np.append(data, np.array([t, CL, CD], ndmin=2), axis=0)
        np.savetxt(f'{output_dir}/coeffs.dat', data)
    PETSc.Sys.Print(f't:{t:08f}\t\t CL:{CL:08f} \t\tCD::{CD:08f}')

callbacks = [
    gym.io.ParaviewCallback(interval=10, filename=pvd_out, postprocess=compute_vort),
    gym.io.GenericCallback(callback=forces, interval=1)
]

# Simple opposition control on lift
def controller(t, y):
    CL, CD = y
    return -2*CL

# callbacks = []
solver = gym.IPCSSolver(cyl, dt=dt, callbacks=callbacks, actuated=True)
solver.solve(Tf)