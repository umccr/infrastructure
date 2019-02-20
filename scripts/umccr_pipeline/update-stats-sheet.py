#!/usr/bin/env python3

import os, sys, json
from pprint import pprint
from collections import OrderedDict, Counter

GENOME_SIZE=3200000000
LANES=[1,2,3,4]


class Bcl2fastqStats:
    def __init__(self, stats_file):
        self.stats_file_name = stats_file
        with open(stats_json) as fp:
            data = json.load(fp)

            self.flowcell = data[u'Flowcell'] # str
            self.run_number = data[u'RunNumber'] # int
            self.run_id = data[u'RunId']
            self.samples_in_lanes = {}

            # conversion results
            self.total_reads_PF = 0
            self.total_bases_PF = 0
            conversion_stats = data[u'ConversionResults']
            self.lane_stats = {}
            for lane_number in LANES:
                self.lane_stats[lane_number] = {'reads_raw':0, 'reads_PF':0, 'bases_PF':0,
                                                'reads_undetermined':0, 'bases_undetermined':0, 'reads_demuxed':0, 'bases_demuxed':0,
                                                'samples':{}}

            for lane_stat in conversion_stats:
                lane_number = lane_stat[u'LaneNumber']
                self.lane_stats[lane_number]['reads_raw'] = lane_stat[u'TotalClustersRaw']
                self.lane_stats[lane_number]['reads_PF'] = lane_stat[u'TotalClustersPF']
                self.lane_stats[lane_number]['bases_PF'] = lane_stat[u'Yield']
                self.lane_stats[lane_number]['reads_undetermined'] = lane_stat[u'Undetermined'][u'NumberReads']
                self.lane_stats[lane_number]['bases_undetermined'] = lane_stat[u'Undetermined'][u'Yield']

                self.total_reads_PF += self.lane_stats[lane_number]['reads_PF'] 
                self.total_bases_PF += self.lane_stats[lane_number]['bases_PF'] 

                demux_results = lane_stat[u'DemuxResults']
                for sample_stat in demux_results:
                    sample_id = sample_stat[u'SampleId']
                    sample_name = sample_stat[u'SampleName']
                    sample_reads = sample_stat[u'NumberReads']
                    sample_bases = sample_stat[u'Yield']

                    self.lane_stats[lane_number]['samples'][(sample_id, sample_name)] = {'reads':sample_reads, 'bases':sample_bases}
                    self.lane_stats[lane_number]['reads_demuxed'] += sample_reads
                    self.lane_stats[lane_number]['bases_demuxed'] += sample_bases

                    if self.samples_in_lanes.get((sample_id, sample_name)) is None:
                        self.samples_in_lanes[(sample_id, sample_name)] = [0] * len(LANES)
                    self.samples_in_lanes[(sample_id, sample_name)][lane_number-1] = 1

    def get_total_bases_undetermined(self):
        return sum([self.lane_stats[lane_number]['bases_undetermined'] for lane_number in LANES])

    def merge(self, other):
        if self.run_id != other.run_id:
            return False

        # check other metrics
        for lane_number, lane_stat in other.lane_stats.items():
            if other.lane_stats[lane_number]['reads_PF'] == 0:
                continue

            if other.lane_stats[lane_number]['reads_PF'] != self.lane_stats[lane_number]['reads_PF']:
                raise Exception("Read PF are not the same - Lane {}. Reads 'self' = {}, 'other' = {}".format(lane_number, 
                                                                                self.lane_stats[lane_number]['reads_PF'],
                                                                                other.lane_stats[lane_number]['reads_PF'] ))
            #if self.lane_stats[lane_number]['reads_PF'] == other.lane_stats[lane_number]['reads_PF']:
            else:
                #assert self.lane_stats[lane_number]['reads_PF'] == other.lane_stats[lane_number]['reads_PF']
                if self.lane_stats[lane_number]['bases_PF'] != other.lane_stats[lane_number]['bases_PF']:
                    raise Exception('[{}] Base accounting failed - {} vs {}'.format(self.run_id,
                                                self.lane_stats[lane_number]['bases_PF'], other.lane_stats[lane_number]['bases_PF']))

                undetermined_self = self.lane_stats[lane_number]['reads_undetermined'] - other.lane_stats[lane_number]['reads_demuxed']
                undetermined_other = other.lane_stats[lane_number]['reads_undetermined'] - self.lane_stats[lane_number]['reads_demuxed']

                if undetermined_self != undetermined_other:
                    raise Exception("Mismatch of undetermined reads after matching up demultiplexed reads - Lane {}".format(lane_number))

                # update the undetermined reads
                self.lane_stats[lane_number]['reads_undetermined'] = undetermined_self
                self.lane_stats[lane_number]['bases_undetermined'] = self.lane_stats[lane_number]['bases_undetermined'] - other.lane_stats[lane_number]['bases_demuxed']


                # update the demultiplexed reads
                self.lane_stats[lane_number]['reads_demuxed'] += other.lane_stats[lane_number]['reads_demuxed']
                self.lane_stats[lane_number]['bases_demuxed'] += other.lane_stats[lane_number]['bases_demuxed']

                # add samples in 'other' into 'self'
                for sample, sample_info in other.lane_stats[lane_number]['samples'].items():
                    #print(sample, sample_info)
                    if self.lane_stats[lane_number]['samples'].get(sample) is None:
                        self.lane_stats[lane_number]['samples'][sample] = {'reads':0, 'bases':0}
                    self.lane_stats[lane_number]['samples'][sample]['reads'] += sample_info['reads']
                    self.lane_stats[lane_number]['samples'][sample]['bases'] += sample_info['bases']
                    #print(sample, sample_info)

        for sample, membership in other.samples_in_lanes.items():
            self.samples_in_lanes[sample] = membership                    

        return True


    def __hash__(self):
        return hash(self.run_id)


    def __cmp__(self, other):
        return cmp(self.run_id, other.run_id)


    def __str__(self):
        all_sample_names = sorted(self.samples_in_lanes.items(), key=lambda kv: kv[1], reverse=True)
        all_lanes = set([])
        for lane_number, lane_data in self.lane_stats.items():
            all_lanes.add(lane_number)
        all_lanes = sorted(list(all_lanes))

        total_genome_equivalent = 0
        output = [] 
        for sample_id_value, sample_lane_membership in all_sample_names:
            sample_id, sample_name = sample_id_value
            row = [self.run_id, sample_id, sample_name]
            total_sample_reads = 0
            total_sample_bases = 0
            for lane_number in all_lanes:
                lane_data = self.lane_stats.get(lane_number)

                sample_reads = lane_data['samples'].get((sample_id, sample_name))
                if sample_reads is not None:
                    row += ['{:,}'.format(sample_reads['reads']), '{:.2%}'.format(sample_reads['reads']/float(lane_data['reads_PF']))]
                    total_sample_reads += sample_reads['reads']
                    total_sample_bases += sample_reads['bases']
                else:
                    #row += ['{:,}'.format(0), '{:.2%}'.format(0.0)]
                    row += ['.', '.']

            genome_equivalent = total_sample_bases/float(GENOME_SIZE)
            total_genome_equivalent += genome_equivalent
            row += ['{:,}'.format(total_sample_reads), '{:.2%}'.format(total_sample_reads/float(self.total_reads_PF))]
            row += ['{:.2f}'.format(genome_equivalent)]
            row_str = '\t'.join([str(v) for v in row])
            output.append(row_str)

        total_undetermined = 0
        total_PF = 0
        row = [self.run_id, 'Undetermined', 'Undetermined']
        total = [self.run_id, '.', 'TOTAL']
        for lane_number in all_lanes:
            lane_data = self.lane_stats.get(lane_number)
            if lane_data['reads_PF'] == 0:
                row += ['.', '.']
            else:
                row += ['{:,}'.format(lane_data['reads_undetermined']), '{:.2%}'.format(lane_data['reads_undetermined']/float(lane_data['reads_PF']))]

            if lane_data['reads_PF'] == 0:
                total += ['.', '.']
            else:
                total_undetermined += lane_data['reads_undetermined']
                total_PF += lane_data['reads_PF']
                total += ['{:,}'.format(lane_data['reads_PF']), '{:.2%}'.format(lane_data['reads_PF']/float(self.total_reads_PF))]

        genome_equivalent = self.get_total_bases_undetermined()/float(GENOME_SIZE)
        total_genome_equivalent += genome_equivalent
        row += ['{:,}'.format(total_undetermined), '{:.2%}'.format(total_undetermined/float(total_PF))]
        row += ['{:.2f}'.format(genome_equivalent)]
        row_str = '\t'.join([str(v) for v in row])
        total += ['{:,}'.format(total_PF), '{:.2%}'.format(total_PF/float(self.total_reads_PF))]
        total += ['{:.2f}'.format(total_genome_equivalent)]
        total_str = '\t'.join([str(v) for v in total])
        
        output.append(row_str)
        output.append(total_str)

        return '\n'.join(output)
    


def sample_name_cmp(item1, item2):
    return cmp(item1[0], item2[0])

def get_stats(stats_json):
    with open(stats_json) as fp:
        stats = json.load( fp )

        run_id = stats[u'RunId']
        conversion_stats = stats[u'ConversionResults']
        sample_stats = Counter()
        sample_bases = Counter()
        sample_mapping = {}
        total_yield = 0
        total_reads = 0

        total_undetermined = 0
        for value in conversion_stats:
            if type(value) is dict and value.get('DemuxResults') is not None:
                demulx_stats = value['DemuxResults']
                for sample in demulx_stats:
                    total_reads += sample['NumberReads']
                    total_yield += sample['Yield']
                    sample_stats[ sample['SampleId'] ] += sample['NumberReads']
                    sample_bases[ sample['SampleId'] ] += sample['Yield']
                    sample_mapping[ sample['SampleId'] ] = sample['SampleName']
            if type(value) is dict and value.get('Undetermined') is not None:
                demulx_stats = value['Undetermined']
                sample_stats['Undetermined'] += demulx_stats['NumberReads']
                sample_bases['Undetermined'] += demulx_stats['Yield']
                total_reads += demulx_stats['NumberReads']
                total_yield += demulx_stats['Yield']
                sample_mapping['Undetermined'] = 'Undetermined'

        read_stats = OrderedDict( sorted(sample_stats.items(), cmp=sample_name_cmp) )
        base_stats = OrderedDict( sorted(sample_bases.items(), cmp=sample_name_cmp) )
        for sample, reads in read_stats.iteritems():
            run_fraction = float(reads) / total_reads * 100
            coverage     = float( sample_bases[ sample ] ) / GENOME_SIZE
            print('\t'.join( [run_id, sample, str(reads), str( sample_bases[ sample ] ), '%.2f%%'%(run_fraction), str(coverage), sample_mapping[sample] ] ))
        print('\t'.join( [run_id, 'TOTAL', str(total_reads), str(total_yield), '100%', str( float(total_yield)/GENOME_SIZE )] ))
        print()


if __name__=='__main__':

    if len(sys.argv) > 1:
        stats_jsons = sys.argv[1:]
    else:
        stats_jsons = []
        for stats_json in sys.stdin:
            stats_jsons.append(stats_json.strip())

    all_stats = []
    for stats_json in stats_jsons:
        #get_stats(stats_json)
        stats = Bcl2fastqStats(stats_json)

        merged = False
        for stat in all_stats:
            if stat.merge(stats):
                merged = True

        if not merged:
            all_stats.append(stats)

    for stats in all_stats:
        print(stats)
        print()
            

