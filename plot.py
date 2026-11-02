# I use AI Claude Opus 4.8 to produce this code entirely

import matplotlib
matplotlib.use("Agg")   # no display needed, just save to file
import matplotlib.pyplot as plt

years = []
pops = []
with open("/tmp/popdata.csv") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        year, pop = line.split(",")
        years.append(int(year))
        pops.append(int(pop))

plt.plot(years, pops, marker="o")
plt.xlabel("Year")
plt.ylabel("Population")
plt.title("NSW Population Over Time")
plt.savefig("/root/population.png")