import numpy as np
from flightgym import QuadrotorEnv_v1

env = QuadrotorEnv_v1()

env.connectUnity()      # <-- THIS IS THE MAGIC LINE


num_envs = env.getNumOfEnvs()
obs_dim = env.getObsDim()
act_dim = env.getActDim()
extra_dim = len(env.getExtraInfoNames())

print("Num envs:", num_envs)
print("Obs dim:", obs_dim)
print("Act dim:", act_dim)
print("Extra dim:", extra_dim)

obs = np.zeros((num_envs, obs_dim), dtype=np.float32)
reward = np.zeros((num_envs, 1), dtype=np.float32)
done = np.zeros((num_envs, 1), dtype=bool)
extra = np.zeros((num_envs, extra_dim), dtype=np.float32)

init = np.zeros((num_envs, obs_dim), dtype=np.float32)
env.reset(init)

action = np.zeros((num_envs, act_dim), dtype=np.float32)

for i in range(10):
    env.step(action, obs, reward, done, extra)
    print("Step:", i, "Reward:", reward[0], "Done:", done[0])
