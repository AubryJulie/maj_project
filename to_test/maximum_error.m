% computation of the maximum angle error and maximum length error
d = 0.2;
c = 340;
%%timer 1Mhz
delay12 = [0:1:590];
delay23 = [0:1:590];

angle12 = arcsin(delay12*(10^-6)*c/d)
angle23 = arcsin(delay12*(10^-6)*c/d)

distance = d*sin(angle23-30)/(2*sin(angle12-angle23+60))


%%timer 500khz
delay12 = [0:2:590];
delay23 = [0:2:590];

angle12 = arcsin(delay12*(10^-6)*c/d)
angle23 = arcsin(delay12*(10^-6)*c/d)

distance = d*sin(angle23-30)/(2*sin(angle12-angle23+60))


%%timer 250khz
delay12 = [0:4:590];
delay23 = [0:4:590];

angle12 = arcsin(delay12*(10^-6)*c/d)
angle23 = arcsin(delay12*(10^-6)*c/d)

distance = d*sin(angle23-30)/(2*sin(angle12-angle23+60))