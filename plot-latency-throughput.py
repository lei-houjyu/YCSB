import sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.pyplot import MultipleLocator

if len(sys.argv) < 3:
    print('Usage: python plot-latency-throughput.py output_name file_name0 ...')
    exit()

output_name = sys.argv[1]

data = {'read_t':[], 'read_l':[], 'write_t':[], 'write_l':[], 'overall_t':[], 'overall_l':[]}

for i in range(2, len(sys.argv)):
    file_name = sys.argv[i]
    print(file_name)
    with open(file_name, 'r') as f:
        line = f.readline()
        while line:
            word = line.split()
            if len(word) >= 3:
                if word[0] == '[OVERALL],':
                    read_cnt = 0
                    write_cnt = 0
                    if word[1] == 'RunTime(ms),':
                        runtime = int(word[2])
                    elif word[1] == 'Throughput(ops/sec),':
                        data['overall_t'].append(float(word[2]))
                        data['overall_l'].append(0)
                elif word[0] == '[READ],':
                    if word[1] == 'Operations,':
                        read_cnt = int(word[2])
                        data['read_t'].append(read_cnt * 1000.0 / runtime)
                    elif word[1] == 'AverageLatency(us),':
                        data['read_l'].append(float(word[2]) / 1000000)
                        data['overall_l'][-1] = read_cnt * data['read_l'][-1]
                elif word[0] == '[UPDATE],' or word[0] == '[INSERT],':
                    if word[1] == 'Operations,':
                        write_cnt = int(word[2])
                        data['write_t'].append(write_cnt * 1000.0 / runtime)
                    elif word[1] == 'AverageLatency(us),':
                        data['write_l'].append(float(word[2]) / 1000000)
                        data['overall_l'][-1] = write_cnt * data['write_l'][-1]
                        data['overall_l'][-1] /= read_cnt + write_cnt
            line = f.readline()

plt.figure()
plt.plot(data['read_t'], data['read_l'], '-o', label='read')
plt.plot(data['write_t'], data['write_l'], '-+', label='write')
plt.plot(data['overall_t'], data['overall_l'], '-^', label='overall')
x_loc = MultipleLocator(2500)
# y_loc = MultipleLocator(10)
ax = plt.gca()
ax.xaxis.set_major_locator(x_loc)
# ax.yaxis.set_major_locator(y_loc)
plt.xlim(29000, 56000)
plt.ylim(-10, 120)
plt.xlabel('Throughput (ops/sec)')
plt.ylabel('Latency (sec)')
plt.legend()
plt.savefig(output_name)
plt.close()