import sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

if len(sys.argv) < 2:
    print('Usage: python plot-latency-throughput.py range')
    exit()

factor = int(sys.argv[1])
data = {'read_t':[], 'read_l':[], 'write_t':[], 'write_l':[], 'overall_t':[], 'overall_l':[]}

for i in range(1, factor + 1):
    file_name = 'ycsb-' + str(i * 10000) + '.out'
    print(file_name)
    with open(file_name, 'r') as f:
        line = f.readline()
        while line:
            word = line.split()
            if len(word) >= 3:
                if word[0] == '[OVERALL],':
                    if word[1] == 'RunTime(ms),':
                        runtime = int(word[2])
                    elif word[1] == 'Throughput(ops/sec),':
                        data['overall_t'].append(float(word[2]))
                elif word[0] == '[READ],':
                    if word[1] == 'Operations,':
                        read_cnt = int(word[2])
                        data['read_t'].append(read_cnt * 1000.0 / runtime)
                    elif word[1] == 'AverageLatency(us),':
                        data['read_l'].append(float(word[2]) / 1000000)
                elif word[0] == '[UPDATE],':
                    if word[1] == 'Operations,':
                        write_cnt = int(word[2])
                        data['write_t'].append(write_cnt * 1000.0 / runtime)
                    elif word[1] == 'AverageLatency(us),':
                        data['write_l'].append(float(word[2]) / 1000000)
                        l = (read_cnt * data['read_l'][-1] + write_cnt * data['write_l'][-1]) / (read_cnt + write_cnt)
                        data['overall_l'].append(l)
            line = f.readline()

# plt.figure()
# plt.plot(data['read_t'], data['read_l'], '-^', label='read')
# plt.xlabel('Throughput (ops/sec)')
# plt.ylabel('Latency (sec)')
# plt.legend()
# plt.savefig('read-lat-thru.jpg')
# plt.close()

# plt.figure()
# plt.plot(data['write_t'], data['write_l'], '-^', label='write')
# plt.xlabel('Throughput (ops/sec)')
# plt.ylabel('Latency (sec)')
# plt.legend()
# plt.savefig('write-lat-thru.jpg')
# plt.close()

plt.figure()
plt.plot(data['read_t'], data['read_l'], '-o', label='read')
plt.plot(data['write_t'], data['write_l'], '-+', label='write')
plt.plot(data['overall_t'], data['overall_l'], '-^', label='overall')
plt.xlabel('Throughput (ops/sec)')
plt.ylabel('Latency (sec)')
plt.legend()
plt.savefig('overall-lat-thru.jpg')
plt.close()