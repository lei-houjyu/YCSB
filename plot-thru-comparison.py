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
    # workloads = ['Load', 'A', 'B', 'C', 'D', 'E', 'F', 'G']
    workloads = ['Cluster15', 'Cluster31']

    speedup = {}
    speedup['Baseline'] = [1 for i in range(len(data['Baseline']))]
    speedup['Rubble'] = [data['Rubble'][i] / data['Baseline'][i] for i in range(len(data['Baseline']))]
    
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
        rects.append(ax.bar(center, speedup[key_list[i]], width, label=key_list[i]))

    plt.ylim([0, 2.0])
    ax.set_ylabel('Throughput per Core (op/s)', fontsize=fs)
    # ax.set_xlabel('YCSB Workload', fontsize=fs)
    ax.set_xlabel('Twitter Workload', fontsize=fs)
    ax.set_xticks(x, workloads, fontsize=fs)
    plt.yticks(fontsize=fs)

    ax.legend(loc='upper right', fontsize=fs-5)

    # for r in rects:
    #     ax.bar_label(r, labels=data[], padding=3, rotation='vertical', fmt='%d', fontsize=fs-5)
    ax.bar_label(rects[0], labels=data['Baseline'], label_type='center', padding=3, rotation='vertical', fmt='%d', fontsize=fs-5)
    ax.bar_label(rects[1], labels=data['Rubble'], label_type='center', padding=3, rotation='vertical', fmt='%d', fontsize=fs-5)

    fig.tight_layout()

    plt.savefig(figure_name)
    plt.close()

# cf = 1
data_cf1_rf2 = {'Baseline' : [55397.7, 57376.1, 70999.0, 73104.8, 142066.6, 9768.6, 53920.6, 34313.9],
                'Rubble'   : [71892.5, 60179.9, 70387.6, 72413.9, 145274.9, 9922.2, 57003.3, 37292.0]}
plot(data_cf1_rf2, 'ycsb-thru-cf1-rf2.pdf', 120000)

data_cf1_rf3 = {'Baseline' : [60613.9, 62970.3, 103379.8, 110945.5, 197230.9, 14907.4, 60620.4, 36431.3],
                'Rubble'   : [88608.0, 68124.2, 103014.5, 108405.0, 214729.0, 14898.1, 66644.9, 41191.7]}
plot(data_cf1_rf3, 'ycsb-thru-cf1-rf3.pdf', 120000)

data_cf1_rf4 = {'Baseline' : [62201.7, 67578.8, 135206.4, 144727.7, 242070.7, 19591.6, 65303.8, 38252.5],
                'Rubble'   : [97100.6, 75434.6, 135405.5, 145785.3, 283505.0, 19844.3, 73103.6, 44067.5]}
plot(data_cf1_rf4, 'ycsb-thru-cf1-rf4.pdf', 120000)

data_cf1_rf3_twitter = {'Baseline' : [86297.1, 138576.5],
                        'Rubble'  : [129971.2, 171034.6]}
plot(data_cf1_rf3_twitter, 'ycsb-thru-cf1-rf3-twitter.pdf', 120000)

# cf = 2
data_cf2_rf2 = {'Baseline' : [62761.1, 60312.3, 103883.2, 116866.8, 177417.4, 15538.5, 57437.6, 38253.9],
                'Rubble'   : [87830.0, 63635.1, 105429.3, 117357.1, 191688.4, 15559.3, 61047.3, 41938.3]}
plot(data_cf2_rf2, 'ycsb-thru-cf2-rf2.pdf', 120000)

data_cf2_rf3 = {'Baseline' : [63256.4, 66144.5, 147880.9, 179210.9, 240038.4, 22938.7, 63413.5, 39747.9],
                'Rubble'   : [104654.5, 73928.1, 149695.4, 178996.0, 284420.8, 23228.8, 70675.5, 45334.8]}
plot(data_cf2_rf3, 'ycsb-thru-cf2-rf3.pdf', 120000)

data_cf2_rf4 = {'Baseline' : [63094.5, 68978.5, 188055.2, 239391.9, 290381.1, 30749.0, 66342.0, 39744.4],
                'Rubble'   : [113663.8, 77472.5, 190589.2, 234850.0, 359413.3, 31399.7, 74575.2, 45792.1]}
plot(data_cf2_rf4, 'ycsb-thru-cf2-rf4.pdf', 120000)

data_cf2_rf2_optane = {'Baseline' : [66230.8, 76277.9, 158189.1, 205095.6, 215183.3, 24116.1, 69537.8, 48195.2],
                        'Rubble'  : [91294.4, 81421.5, 160255.8, 200155.1, 228017.7, 24505.4, 75128.8, 53090.0]}
plot(data_cf2_rf2_optane, 'ycsb-thru-cf2-rf2-optane.pdf', 120000)

data_cf2_rf3_small = {'Baseline' : [115926.3, 83428.1, 179334.7, 209447.5, 336658.8],
                      'Rubble'   : [129706.2, 90280.7, 179303.6, 209428.5, 358187.6]}
plot(data_cf2_rf3_small, 'ycsb-thru-cf2-rf3-small.pdf', 400000)
