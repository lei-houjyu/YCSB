import sys
import numpy as np
import matplotlib.pyplot as plt

# for w in 'load' 'a' 'b' 'c' 'd'; do 
#   grep Throughput ycsb-baseline-$w-2-shard-2-replica.out \
#     | tail -n 1 \
#     | awk '{printf "%.1f, ",$(NF)}'; 
# done

def plot(data, figure_name, ymax):
    workloads = ['Load', 'A', 'B', 'C', 'D']

    x = np.arange(len(workloads))
    config_num = len(data.keys())
    width = 1.0 / (1 + config_num)

    plt.figure()
    fig, ax = plt.subplots()
    rects = list()
    key_list = list(data)
    for i in range(config_num):
        center = x + (i - (config_num - 1) / 2.0) * width
        rects.append(ax.bar(center, data[key_list[i]], width, label=key_list[i]))

    plt.ylim([0, ymax])
    ax.set_ylabel('Throughput (op/s)')
    ax.set_xlabel('YCSB Workload')
    ax.set_xticks(x, workloads)
    ax.legend()

    for r in rects:
        ax.bar_label(r, padding=3, rotation='vertical', fmt='%d', fontsize=5)

    fig.tight_layout()

    plt.savefig(figure_name)
    plt.close()

# cf = 1
data_cf1_rf2 = {'Baseline' : [47995.6, 56342.2, 70080.3,  72842.0,  141819.8],
                'Rubble'   : [59975.4, 59963.4, 70085.2,  72621.9,  147123.7]}
plot(data_cf1_rf2, 'ycsb-thru-cf1-rf2.pdf', 250000)

data_cf1_rf3 = {'Baseline' : [60016.1, 61896.6, 100731.0, 109019.6, 196904.7],
                'Rubble'   : [70422.2, 66571.0, 102367.4, 107208.7, 204329.1]}
plot(data_cf1_rf3, 'ycsb-thru-cf1-rf3.pdf', 250000)

data_cf1_rf4 = {'Baseline' : [61342.6, 65181.9, 119591.1, 139781.5, 233349.1],
                'Rubble'   : [80919.2, 72169.6, 119611.9, 139770.2, 238580.9]}
plot(data_cf1_rf4, 'ycsb-thru-cf1-rf4.pdf', 250000)

# cf = 2
data_cf2_rf2 = {'Baseline' : [62461.3, 59288.4, 105112.7, 119397.6, 181227.5],
                'Rubble'   : [85827.9, 64057.8, 104853.7, 111539.0, 194232.3]}
plot(data_cf2_rf2, 'ycsb-thru-cf2-rf2.pdf', 250000)

data_cf2_rf3 = {'Baseline' : [63065.4, 64053.5, 119702.9, 139843.8, 235847.2],
                'Rubble'   : [87692.8, 70942.4, 119676.9, 139818.1, 237947.0]}
plot(data_cf2_rf3, 'ycsb-thru-cf2-rf3.pdf', 250000)

data_cf2_rf4 = {'Baseline' : [61846.8, 66926.5, 119728.4, 139888.0, 236210.5],
                'Rubble'   : [87856.9, 73561.5, 119747.6, 139887.0, 239122.9]}
plot(data_cf2_rf4, 'ycsb-thru-cf2-rf4.pdf', 250000)

data_cf2_rf3_small = {'Baseline' : [115926.3, 83428.1, 179334.7, 209447.5, 336658.8],
                      'Rubble'   : [129706.2, 90280.7, 179303.6, 209428.5, 358187.6]}
plot(data_cf2_rf3_small, 'ycsb-thru-cf2-rf3-small.pdf', 400000)
