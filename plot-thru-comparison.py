import sys
import numpy as np
import matplotlib.pyplot as plt

# for w in 'load' 'a' 'b' 'c' 'd'; do 
#   grep Throughput ycsb-baseline-$w-2-shard-2-replica.out \
#     | tail -n 1 \
#     | awk '{printf "%.1f, ",$(NF)}'; 
# done

fs = 20
cpu_num = 4

def plot(data, figure_name, ymax):
    for key in data:
        for i in range(len(data[key])):
            data[key][i] /= cpu_num
    workloads = ['Load', 'A', 'B', 'C', 'D']

    x = np.arange(len(workloads))
    config_num = len(data.keys())
    width = 1.0 / (1 + config_num)

    plt.figure()
    # fig, ax = plt.subplots(figsize=(5,4))
    fig, ax = plt.subplots()
    rects = list()
    key_list = list(data)
    for i in range(config_num):
        center = x + (i - (config_num - 1) / 2.0) * width
        rects.append(ax.bar(center, data[key_list[i]], width, label=key_list[i]))

    plt.ylim([0, ymax])
    ax.set_ylabel('Throughput per Core (op/s)', fontsize=fs)
    ax.set_xlabel('YCSB Workload', fontsize=fs)
    ax.set_xticks(x, workloads, fontsize=fs)
    plt.yticks(fontsize=fs)

    ax.legend(loc='upper left', fontsize=fs)

    for r in rects:
        ax.bar_label(r, padding=3, rotation='vertical', fmt='%d', fontsize=fs)

    fig.tight_layout()

    plt.savefig(figure_name)
    plt.close()

# cf = 1
data_cf1_rf2 = {'Baseline' : [55397.7, 57376.1, 70999.0, 73104.8, 142066.6],
                'Rubble'   : [71892.5, 60179.9, 70387.6, 72413.9, 145274.9]}
plot(data_cf1_rf2, 'ycsb-thru-cf1-rf2.pdf', 120000)

data_cf1_rf3 = {'Baseline' : [60613.9, 62970.3, 103379.8, 110945.5, 197230.9],
                'Rubble'   : [88608.0, 68124.2, 103014.5, 108405.0, 214729.0]}
plot(data_cf1_rf3, 'ycsb-thru-cf1-rf3.pdf', 120000)

data_cf1_rf4 = {'Baseline' : [62201.7, 67578.8, 135206.4, 144727.7, 242070.7],
                'Rubble'   : [101701.5, 75434.6, 135405.5, 145785.3, 283505.0]}
plot(data_cf1_rf4, 'ycsb-thru-cf1-rf4.pdf', 120000)

data_cf1_rf3_optane = {'Baseline' : [64569.9, 78641.7, 209259.0, 296856.3, 280363.4],
                'Rubble'   : [88782.1, 86846.8, 210619.4, 295563.6, 317436.8]}
plot(data_cf1_rf3_optane, 'ycsb-thru-cf1-rf3-optane.pdf', 350000)

# cf = 2
data_cf2_rf2 = {'Baseline' : [62761.1, 60312.3, 103883.2, 116866.8, 177417.4],
                'Rubble'   : [87830.0, 63635.1, 105429.3, 117357.1, 191688.4]}
plot(data_cf2_rf2, 'ycsb-thru-cf2-rf2.pdf', 120000)

data_cf2_rf3 = {'Baseline' : [63256.4, 66144.5, 147880.9, 179210.9, 240038.4],
                'Rubble'   : [104654.5, 73928.1, 149695.4, 178996.0, 284420.8]}
plot(data_cf2_rf3, 'ycsb-thru-cf2-rf3.pdf', 120000)

data_cf2_rf4 = {'Baseline' : [63094.5, 68978.5, 188055.2, 239391.9, 290381.1],
                'Rubble'   : [113663.8, 77472.5, 190589.2, 234850.0, 359413.3]}
plot(data_cf2_rf4, 'ycsb-thru-cf2-rf4.pdf', 120000)

data_cf2_rf3_small = {'Baseline' : [115926.3, 83428.1, 179334.7, 209447.5, 336658.8],
                      'Rubble'   : [129706.2, 90280.7, 179303.6, 209428.5, 358187.6]}
plot(data_cf2_rf3_small, 'ycsb-thru-cf2-rf3-small.pdf', 400000)
