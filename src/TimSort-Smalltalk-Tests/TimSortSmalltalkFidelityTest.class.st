"
I check that TimSort-Smalltalk is faithful to timsort.c (commit `fd70381039da47507984b9c1306914828871afbf`): for the same input and the same answers of the comparison, the sorters make the same comparisons in the same order and leave the same permutation.

The expectations were computed by the C program of `#traceProgram`, compiled with timsort.c (`cc -O2 -DNDEBUG trace.c timsort.c`) and run once per case. It sorts the positions 0 to n - 1 of a key array of `TimSortSmalltalkTestData` by `lt(i, j) = key[i] < key[j]`, with `list_sort_impl(list, reverse, 0, 1, lt, NULL)` (CPython's default binary insertion), and prints the number of comparisons, the hash of the sequence of compared pairs and the hash of the permutation (`TimSortSmalltalkTrace`). `#expectedTraces` holds them as `(shape n seed reverse comparisons traceHash permutationHash)`, with the shapes numbered from 0 as in the C program.

The tests sort the same positions with each sorter:

- `TimSortSmalltalkLessThanSorter` with the block `lt`,
- `TimSortSmalltalkSortBlockSorter` with the sortBlock `[ :i :j | (lt value: j value: i) not ]` (so that its strict less-than is `lt` again),
- and `TimSortSmalltalkNaturalOrderSorter` on TimSortSmalltalkTraceKeys.

`merge_compute_minrun` and `powerloop` are static functions of timsort.c; `#expectedMinimumRunLengths` and `#expectedPowers` were printed by the program of `#policyProgram`, which includes timsort.c.
"
Class {
	#name : 'TimSortSmalltalkFidelityTest',
	#superclass : 'TestCase',
	#category : 'TimSort-Smalltalk-Tests',
	#package : 'TimSort-Smalltalk-Tests'
}

{ #category : 'expectations' }
TimSortSmalltalkFidelityTest class >> expectedInconsistentTraces [
	"(n seed reverse chaos comparisons traceHash permutationHash), from #traceProgram: the keys are random (shape 0), and the comparison lies when the next random number is a multiple of chaos"

	^ #(
		(2 42 0 2 1 1000003 1000003) (2 42 0 50 1 1000003 1000003) (2 42 1 2 1 1 1)
		(3 42 0 2 3 198638812 7993015) (3 42 0 50 2 28937083 12986021) (3 42 1 2 4 41834044 1000005)
		(5 42 0 2 4 237606367 720287925) (5 42 0 50 7 11650335 400049579) (5 42 1 2 4 143665965 720287925)
		(8 42 0 2 18 952221994 116971875) (8 42 0 50 18 252499074 565939429) (8 42 1 2 8 384683819 698807314)
		(33 42 0 2 115 151509874 887716535) (33 42 0 50 125 476555870 550234437) (33 42 1 2 123 125254919 329786436)
		(65 42 0 2 299 814807845 352995398) (65 42 0 50 313 259829477 596795700) (65 42 1 2 303 515916110 736336633)
		(100 42 0 2 501 176851913 20981752) (100 42 0 50 524 474811257 397215247) (100 42 1 2 511 210378146 891995822)
		(257 42 0 2 1591 738230363 880793343) (257 42 0 50 1622 182944071 429241403) (257 42 1 2 1666 789072992 862697961)
		(1000 42 0 2 8278 926119684 921485040) (1000 42 0 50 7630 328001589 2972362) (1000 42 1 2 8114 130687274 162823767)
		(5000 42 0 2 52332 742160057 121223501) (5000 42 0 50 41061 850531139 772542113) (5000 42 1 2 52449 843074088 543323027)
		(20000 7 0 3 249802 614207986 907584530) (20000 7 1 1000 225325 15160611 636154117) (130 2 1 2 660 689931337 765266612)
		(130 41 0 3 607 634799307 836648585) (200 9 0 3 1199 506208951 467542049) (500 11 1 5 3399 633196033 231483224)
		(500 5 0 20 3277 910682642 144946927) )
]

{ #category : 'expectations' }
TimSortSmalltalkFidelityTest class >> expectedMinimumRunLengths [
	"(n minrun), from #policyProgram"

	^ #( (0 0) (1 1) (2 2) (31 31) (63 63) (64 32) (65 33) (127 64) (128 32) (129 33) (255 64) (256 32) (257 33) (1000 63) (1024 32) (4095 64) (4096 32) (4097 33) (10000 40) (65535 64) (65536 32) (100000 49) (1000000 62) (1048576 32) (123456789 59) )
]

{ #category : 'expectations' }
TimSortSmalltalkFidelityTest class >> expectedPowers [
	"(s1 n1 n2 n power), from #policyProgram"

	^ #(
		(0 32 32 1000 5) (32 32 40 1000 4) (0 500 500 1000 1) (0 1 1 2 1)
		(0 10 90 100 1) (90 5 5 100 4) (0 64 64 100000 11) (1000 64 64 100000 10)
		(99800 100 100 100000 10) (12345 678 9012 30000 1) (0 1 1 1000000 20) (999998 1 1 1000000 20) )
]

{ #category : 'expectations' }
TimSortSmalltalkFidelityTest class >> expectedTraces [
	"(shape n seed reverse comparisons traceHash permutationHash), from #traceProgram"

	^ #(
		(0 0 42 0 0 0 0) (1 0 42 0 0 0 0) (8 0 42 0 0 0 0)
		(0 0 42 1 0 0 0) (0 1 42 0 0 0 0) (1 1 42 0 0 0 0)
		(8 1 42 0 0 0 0) (0 1 42 1 0 0 0) (0 2 42 0 1 1000003 1000003)
		(1 2 42 0 1 1000003 1000003) (8 2 42 0 1 1000003 1) (0 2 42 1 1 1 1)
		(0 3 42 0 2 28937083 12986021) (1 3 42 0 4 181732206 5993011) (8 3 42 0 3 198638812 7993015)
		(0 3 42 1 2 38923095 1000005) (0 4 42 0 7 385031661 72853182) (1 4 42 0 7 1240314 44916105)
		(8 4 42 0 5 485052788 71853180) (0 4 42 1 5 637325167 8993020) (0 5 42 0 9 90931732 400049579)
		(1 5 42 0 10 664534993 671406781) (8 5 42 0 6 531449820 578616316) (0 5 42 1 9 968532612 635483696)
		(0 6 42 0 11 608617325 886089692) (1 6 42 0 13 736209103 379116027) (8 6 42 0 8 550046941 376123025)
		(0 6 42 1 12 530971537 610988716) (0 7 42 0 14 841656583 376024478) (1 7 42 0 16 489089040 906912478)
		(8 7 42 0 10 376558643 536411142) (0 7 42 1 16 245586195 233040275) (0 8 42 0 17 53450311 336526507)
		(1 8 42 0 19 804325904 867414507) (8 8 42 0 11 251614443 835803614) (0 8 42 1 19 343330383 972489552)
		(0 32 42 0 119 9850732 769062064) (1 32 42 0 122 885283573 228674159) (2 32 42 0 31 195131411 705645480)
		(3 32 42 0 31 195131411 771249908) (4 32 42 0 31 195131411 705645480) (5 32 42 0 86 336377351 972460346)
		(6 32 42 0 107 754177441 536948180) (7 32 42 0 31 195131411 705645480) (8 32 42 0 51 157274667 737615167)
		(9 32 42 0 31 195131411 705645480) (0 33 42 0 124 327844450 77506387) (1 33 42 0 127 907285176 764727131)
		(2 33 42 0 32 326119858 591996943) (3 33 42 0 32 326119858 339200892) (4 33 42 0 32 326119858 591996943)
		(5 33 42 0 92 62504552 495327752) (6 33 42 0 116 112345593 170285354) (7 33 42 0 32 326119858 591996943)
		(8 33 42 0 53 898472881 497532114) (9 33 42 0 32 326119858 591996943) (0 64 42 0 302 989042092 136808369)
		(1 64 42 0 299 722743127 838389653) (2 64 42 0 63 493907952 283119392) (3 64 42 0 63 493907952 961072140)
		(4 64 42 0 128 506509784 929756817) (5 64 42 0 128 674010644 123649048) (6 64 42 0 266 434836411 883566632)
		(7 64 42 0 63 493907952 283119392) (8 64 42 0 105 358407219 867634612) (9 64 42 0 63 493907952 283119392)
		(0 65 42 0 311 181055882 982303641) (1 65 42 0 308 136225688 672731071) (2 65 42 0 64 844787865 239376400)
		(3 65 42 0 64 844787865 893566127) (4 65 42 0 129 79304418 519332402) (5 65 42 0 129 520511822 600212868)
		(6 65 42 0 273 694889672 260499905) (7 65 42 0 64 844787865 239376400) (8 65 42 0 106 38710437 78914592)
		(9 65 42 0 64 844787865 239376400) (0 128 42 0 733 753485141 39263552) (1 128 42 0 661 105620320 931632836)
		(2 128 42 0 127 624753423 901956705) (3 128 42 0 127 624753423 928221525) (4 128 42 0 379 885644644 307845481)
		(5 128 42 0 256 60042985 932801615) (6 128 42 0 540 11419255 839567154) (7 128 42 0 149 269619702 7177804)
		(8 128 42 0 211 618488070 216454238) (9 128 42 0 127 624753423 901956705) (0 129 42 0 740 616724905 263110304)
		(1 129 42 0 691 199009763 854133318) (2 129 42 0 128 988611254 404556530) (3 129 42 0 128 988611254 639448296)
		(4 129 42 0 383 134311002 426780295) (5 129 42 0 257 73095350 147068827) (6 129 42 0 424 77489609 557724428)
		(7 129 42 0 150 85327044 40439983) (8 129 42 0 213 182652721 222128818) (9 129 42 0 128 988611254 404556530)
		(0 256 42 0 1727 738715238 509553147) (1 256 42 0 1417 404691630 48921473) (2 256 42 0 255 23144214 162095497)
		(3 256 42 0 255 23144214 952332222) (4 256 42 0 986 996839920 968139581) (5 256 42 0 512 777198665 794577073)
		(6 256 42 0 1012 419611864 62364112) (7 256 42 0 423 349919740 392470987) (8 256 42 0 425 317991140 939297057)
		(9 256 42 0 255 23144214 162095497) (0 257 42 0 1728 611651872 292944327) (1 257 42 0 1420 635278806 496143309)
		(2 257 42 0 256 737830028 982152082) (3 257 42 0 256 737830028 111759663) (4 257 42 0 990 974289718 668247415)
		(5 257 42 0 513 559716638 393831349) (6 257 42 0 1157 407615110 669075084) (7 257 42 0 429 170177695 918587489)
		(8 257 42 0 426 425774142 900752410) (9 257 42 0 256 737830028 982152082) (0 512 42 0 3969 946752736 595725244)
		(1 512 42 0 2920 53603007 68427149) (2 512 42 0 511 364566451 218603633) (3 512 42 0 511 364566451 875624179)
		(4 512 42 0 2479 196922210 268904677) (5 512 42 0 1024 568060902 772737974) (6 512 42 0 2399 750844636 369912952)
		(7 512 42 0 733 830645616 462865010) (8 512 42 0 851 271798195 194172792) (9 512 42 0 511 364566451 218603633)
		(0 513 42 0 3972 278714828 108900445) (1 513 42 0 2937 57480878 353802970) (2 513 42 0 512 518649156 287281183)
		(3 513 42 0 512 518649156 555295059) (4 513 42 0 2484 744437731 274765391) (5 513 42 0 1025 166072222 581237897)
		(6 513 42 0 2274 830752746 236377219) (7 513 42 0 738 826961082 179351866) (8 513 42 0 853 49662892 128711069)
		(9 513 42 0 512 518649156 287281183) (0 1000 42 0 8651 571511120 794846981) (1 1000 42 0 5884 609800896 529583986)
		(2 1000 42 0 999 883047342 655762444) (3 1000 42 0 999 883047342 528843766) (4 1000 42 0 7491 344810550 218776617)
		(5 1000 42 0 2000 354545191 250426652) (6 1000 42 0 5587 373634839 156577436) (7 1000 42 0 1430 338586108 44678831)
		(8 1000 42 0 1665 575227885 475643990) (9 1000 42 0 999 883047342 655762444) (0 4096 42 0 43989 671292885 897240150)
		(1 4096 42 0 24299 141582851 366417165) (2 4096 42 0 4095 711613354 611024418) (3 4096 42 0 4095 711613354 890682283)
		(4 4096 42 0 24351 1538856 579548101) (5 4096 42 0 8192 38037003 283783707) (6 4096 42 0 21019 383948069 886003744)
		(7 4096 42 0 5816 904609704 515040579) (8 4096 42 0 6825 59706987 710857496) (9 4096 42 0 4095 711613354 611024418)
		(0 33 42 1 125 962612911 615544997) (1 33 42 1 120 48966253 152778100) (2 33 42 1 32 274104412 339200892)
		(3 33 42 1 32 274104412 591996943) (4 33 42 1 32 274104412 339200892) (5 33 42 1 95 392025176 614046799)
		(6 33 42 1 125 774652275 373008849) (7 33 42 1 32 274104412 339200892) (8 33 42 1 32 274104412 591996943)
		(9 33 42 1 32 274104412 591996943) (0 65 42 1 310 306465782 866486222) (1 65 42 1 297 364272140 881598957)
		(2 65 42 1 64 321601166 893566127) (3 65 42 1 64 321601166 239376400) (4 65 42 1 143 468482685 69477438)
		(5 65 42 1 129 498666486 892154065) (6 65 42 1 291 573124481 501597374) (7 65 42 1 64 321601166 893566127)
		(8 65 42 1 64 321601166 239376400) (9 65 42 1 64 321601166 239376400) (0 257 42 1 1739 283050246 320406919)
		(1 257 42 1 1435 625260558 442283120) (2 257 42 1 256 843622660 111759663) (3 257 42 1 256 843622660 982152082)
		(4 257 42 1 995 676770212 764524831) (5 257 42 1 513 812806727 432639490) (6 257 42 1 1268 414560647 840829616)
		(7 257 42 1 531 270759728 55367420) (8 257 42 1 256 843622660 982152082) (9 257 42 1 256 843622660 982152082)
		(0 1000 42 1 8648 491203133 212963319) (1 1000 42 1 5848 721385658 10481912) (2 1000 42 1 999 248310222 528843766)
		(3 1000 42 1 999 248310222 655762444) (4 1000 42 1 7520 816222265 785774967) (5 1000 42 1 1999 847584516 66119819)
		(6 1000 42 1 5847 658600652 277227230) (7 1000 42 1 1665 224138260 697104238) (8 1000 42 1 999 248310222 655762444)
		(9 1000 42 1 999 248310222 655762444) (0 10000 42 1 120137 320894636 425892483) (1 10000 42 1 59263 306013850 454900605)
		(2 10000 42 1 9999 25935059 982164273) (3 10000 42 1 9999 25935059 976300872) (4 10000 42 1 79627 202892710 273350992)
		(5 10000 42 1 19999 158427219 918496517) (6 10000 42 1 58207 918446370 241379406) (7 10000 42 1 15941 584447319 748893504)
		(8 10000 42 1 9999 25935059 976300872) (9 10000 42 1 9999 25935059 976300872) (0 10000 42 0 120139 599827440 954981830)
		(1 10000 42 0 59385 39819430 257473384) (2 10000 42 0 9999 372192072 976300872) (3 10000 42 0 9999 372192072 982164273)
		(4 10000 42 0 79930 933528023 771180681) (5 10000 42 0 20000 346882944 633936584) (6 10000 42 0 55290 362069372 587067931)
		(7 10000 42 0 15624 444020461 622439046) (8 10000 42 0 16665 972839770 774099681) (9 10000 42 0 9999 372192072 976300872)
		(0 100000 42 0 1531615 44823613 356301890) (1 100000 42 0 598218 620417483 615830668) (6 100000 42 0 615192 388016242 479819321)
		(7 100000 42 0 200289 570976935 764040835) (0 1000 7 0 8646 158574128 503460794) (7 1000 7 1 1216 904858518 10948369)
		(0 10000 7 0 120102 762147545 633482789) (7 10000 7 1 14933 199764779 987434917) (0 1000 12345 0 8692 7019900 546490403)
		(7 1000 12345 1 1240 167633849 973890679) (0 10000 12345 0 120176 91219502 956104930) (7 10000 12345 1 15227 402272365 192765189) )
]

{ #category : 'documentation' }
TimSortSmalltalkFidelityTest class >> policyProgram [
	"The C program that printed #expectedMinimumRunLengths and #expectedPowers"

	^ '#include "timsort.c"
int main(void) {
  long long ns[] = {0,1,2,31,63,64,65,127,128,129,255,256,257,1000,1024,4095,4096,4097,10000,65535,65536,100000,1000000,1048576,123456789};
  for (unsigned i = 0; i < sizeof ns / sizeof *ns; i++) printf("%lld %lld\n", ns[i], (long long)merge_compute_minrun(ns[i]));
  printf("--\n");
  long long cases[][4] = {{0,32,32,1000},{32,32,40,1000},{0,500,500,1000},{0,1,1,2},{0,10,90,100},{90,5,5,100},{0,64,64,100000},{1000,64,64,100000},{99800,100,100,100000},{12345,678,9012,30000},{0,1,1,1000000},{999998,1,1,1000000}};
  for (unsigned i = 0; i < sizeof cases / sizeof *cases; i++) printf("%lld %lld %lld %lld %d\n", cases[i][0],cases[i][1],cases[i][2],cases[i][3], powerloop(cases[i][0],cases[i][1],cases[i][2],cases[i][3]));
}
'
]

{ #category : 'documentation' }
TimSortSmalltalkFidelityTest class >> traceProgram [
	"The C program that computed #expectedTraces (usage: trace n shape seed reverse) and #expectedInconsistentTraces (trace n 0 seed reverse chaos)"

	^ '/* Comparison traces of timsort.c (fd70381) for the fidelity tests of TimSort-Smalltalk.
   The sorted values are the indices 0..n-1 of a key array built by one of the shapes below;
   lt(i, j) = key[i] < key[j].  For every (shape, n, seed, reverse) it prints
   shape n seed reverse comparisons traceHash resultHash
   traceHash folds every compared pair (i, j) in order, resultHash the final permutation:
   h = (h * 1000003 + x) mod 1000000007, starting from 0.
   The same generator is TimSortSmalltalkTestData in TimSort-Smalltalk-Tests.
   With a fifth argument chaos > 0, lt is inconsistent: it draws r = next random (the generator
   goes on after the keys) and answers the opposite of key[i] < key[j] when r % chaos == 0
   (chaos 2: about every other answer is a lie, a coin flip). */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "timsort.h"

#define P 1000000007LL
#define M 1000003LL

static int64_t *keys;
static int64_t count, thash;
static int64_t seed;
static int64_t chaos;

static int64_t next_random(void) { seed = (seed * 16807) % 2147483647; return seed; }

static int lt(timsort_object_t *a, timsort_object_t *b, void *arg)
{
    (void)arg;
    int64_t i = (int64_t)(intptr_t)a, j = (int64_t)(intptr_t)b;
    count++;
    thash = (thash * M + i) % P;
    thash = (thash * M + j) % P;
    if (chaos > 0 && next_random() % chaos == 0)
        return !(keys[i] < keys[j]);
    return keys[i] < keys[j];
}

static void make_keys(int shape, int64_t n)
{
    int64_t i;
    for (i = 0; i < n; i++)
        switch (shape) {
        case 0: keys[i] = next_random() % 1000000; break;           /* random */
        case 1: keys[i] = next_random() % 5; break;                 /* fewUnique */
        case 2: keys[i] = i; break;                                 /* sorted */
        case 3: keys[i] = n - i; break;                             /* reversed */
        case 4: keys[i] = i % 37; break;                            /* sawtooth */
        case 5: keys[i] = i < n / 2 ? i : n - i; break;             /* organPipe */
        case 6: keys[i] = i; break;                                 /* nearlySorted (swaps below) */
        case 7: keys[i] = 0; break;                                 /* sortedChunks (below) */
        case 8: keys[i] = (n - i) / 3; break;                       /* descendingSteps */
        case 9: keys[i] = 7; break;                                 /* allEqual */
        }
    if (shape == 6) {
        int64_t s, swaps = n / 20 + 1;
        for (s = 0; s < swaps && n > 1; s++) {
            int64_t a = next_random() % n, b = next_random() % n, t = keys[a];
            keys[a] = keys[b]; keys[b] = t;
        }
    }
    if (shape == 7) {
        i = 0;
        while (i < n) {
            int64_t len = next_random() % 200 + 1, base = next_random() % 1000000, j;
            for (j = 0; j < len && i < n; j++, i++) keys[i] = base + j * 3;
        }
    }
}

int main(int argc, char **argv)
{
    int64_t n = atoll(argv[1]);
    int shape = atoi(argv[2]);
    int64_t seed0 = atoll(argv[3]);
    int reverse = atoi(argv[4]);
    chaos = argc > 5 ? atoll(argv[5]) : 0;
    int64_t i, rhash = 0;
    timsort_object_t **items = malloc(sizeof(*items) * (n ? n : 1));
    keys = malloc(sizeof(*keys) * (n ? n : 1));
    seed = seed0;
    make_keys(shape, n);
    for (i = 0; i < n; i++) items[i] = (timsort_object_t *)(intptr_t)i;
    timsort_list_t list = { n, items };
    count = 0; thash = 0;
    if (list_sort_impl(&list, reverse, 0, 1, lt, NULL) != 0) { fprintf(stderr, "sort failed\n"); return 1; }
    for (i = 0; i < n; i++) rhash = (rhash * M + (int64_t)(intptr_t)items[i]) % P;
    if (chaos > 0)
        printf("%lld %lld %d %lld %lld %lld %lld\n", (long long)n, (long long)seed0, reverse, (long long)chaos,
               (long long)count, (long long)thash, (long long)rhash);
    else
        printf("%d %lld %lld %d %lld %lld %lld\n", shape, (long long)n, (long long)seed0, reverse,
               (long long)count, (long long)thash, (long long)rhash);
    return 0;
}
'
]

{ #category : 'running' }
TimSortSmalltalkFidelityTest >> assertTracesOf: aSorterBuilder [
	"aSorterBuilder value: keys value: aTrace answers a sorter and the array to sort for one case: check every case of #expectedTraces"

	self class expectedTraces do: [ :each |
		| keys trace sorterAndItems sorter items actual |
		keys := TimSortSmalltalkTestData keysOfShape: each first + 1 size: each second seed: each third.
		trace := TimSortSmalltalkTrace new.
		sorterAndItems := aSorterBuilder value: keys value: trace.
		sorter := sorterAndItems first.
		items := sorterAndItems second.
		each fourth = 1 ifTrue: [ sorter beDescending ].
		sorter sort: items.
		actual := {
			          trace count.
			          trace traceHash.
			          (TimSortSmalltalkTrace hashOf: (self positionsOf: items)) }.
		self
			assert: actual = (each copyFrom: 5 to: 7)
			description: [ 'case ' , each printString , ' answered ' , actual printString ] ]
]

{ #category : 'running' }
TimSortSmalltalkFidelityTest >> defaultTimeLimit [

	^ 120 seconds
]

{ #category : 'running' }
TimSortSmalltalkFidelityTest >> positionsOf: items [

	^ items collect: [ :each |
		  each isInteger
			  ifTrue: [ each ]
			  ifFalse: [ each position ] ]
]

{ #category : 'running' }
TimSortSmalltalkFidelityTest >> tracingLessThan: keys with: aTrace [

	^ [ :i :j |
	  aTrace record: i with: j.
	  (keys at: i + 1) < (keys at: j + 1) ]
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testExpectationsCoverEveryShape [

	self
		assert: (self class expectedTraces collect: [ :each | each first ]) asSet size
		equals: TimSortSmalltalkTestData shapes size
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testInconsistentComparisonTraces [
	"A comparison that contradicts itself gets an unspecified order, but the same as in C, after the same comparisons; and the collection keeps its elements"

	self class expectedInconsistentTraces do: [ :each |
		| data keys trace chaos items sorter actual |
		data := TimSortSmalltalkTestData seed: (each at: 2).
		keys := data keysOfShape: 1 size: (each at: 1).
		trace := TimSortSmalltalkTrace new.
		chaos := each at: 4.
		items := (0 to: keys size - 1) asArray.
		sorter := TimSortSmalltalkLessThanSorter lessThan: [ :i :j |
			          trace record: i with: j.
			          data nextRandom \\ chaos = 0
				          ifTrue: [ ((keys at: i + 1) < (keys at: j + 1)) not ]
				          ifFalse: [ (keys at: i + 1) < (keys at: j + 1) ] ].
		(each at: 3) = 1 ifTrue: [ sorter beDescending ].
		sorter sort: items.
		self assert: items asSet size equals: keys size.
		actual := {
			          trace count.
			          trace traceHash.
			          (TimSortSmalltalkTrace hashOf: items) }.
		self
			assert: actual = (each copyFrom: 5 to: 7)
			description: [ 'case ' , each printString , ' answered ' , actual printString ] ]
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testLessThanSorterTraces [

	self assertTracesOf: [ :keys :trace |
		{
			(TimSortSmalltalkLessThanSorter lessThan: (self tracingLessThan: keys with: trace)).
			(0 to: keys size - 1) asArray } ]
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testMinimumRunLengths [

	self class expectedMinimumRunLengths do: [ :each |
		self assert: (TimSortSmalltalkSorter minimumRunLengthFor: each first) equals: each second ]
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testNaturalOrderSorterTraces [

	self assertTracesOf: [ :keys :trace |
		{
			TimSortSmalltalkNaturalOrderSorter new.
			((1 to: keys size) collect: [ :i | TimSortSmalltalkTraceKey position: i - 1 key: (keys at: i) trace: trace ]) } ]
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testPowers [

	self class expectedPowers do: [ :each |
		self
			assert: (TimSortSmalltalkSorter
					 powerOfRunAt: (each at: 1)
					 length: (each at: 2)
					 nextLength: (each at: 3)
					 total: (each at: 4))
			equals: (each at: 5) ]
]

{ #category : 'tests' }
TimSortSmalltalkFidelityTest >> testSortBlockSorterTraces [

	self assertTracesOf: [ :keys :trace |
		| lessThan |
		lessThan := self tracingLessThan: keys with: trace.
		{
			(TimSortSmalltalkSortBlockSorter sortBlock: [ :i :j | (lessThan value: j value: i) not ]).
			(0 to: keys size - 1) asArray } ]
]
