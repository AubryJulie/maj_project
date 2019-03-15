% computation of the maximum angle error and maximum length error
d = 0.2;
c = 340;
%%timer 1Mhz
d = 0.2;
c = 340;
maximum_delay = d/c
delay12 = [0:10:580];
delay23 = [0:10:580];

angle12 = asin(delay12*(10^-6)*c/d)/pi*180;
angle23 = asin(delay12*(10^-6)*c/d)/pi*180;
% plot delay/angle
figure(1)
plot(delay12,angle12)

l = length(delay23);
max = 0
for i = 2:l
    dif = abs(angle12(i-1)-angle12(i));
    if dif>max
        max = dif;
    end
end
max
distance1 = zeros(1,l);
distance2 = zeros(1,l);
small_angle = zeros(1,l);
big_angle = zeros(1,l);
j=1;
k=1;
for i=1:l
    if angle23(i) <= 26
        small_angle(j) = angle23(i);
        %petit angle
        distance1(j) = d*sin((30-angle23(i))*pi/180)./(2*sin((30+angle23(i)-60)*pi/180));
        j = j+1;
    end
    if angle23(i) > 35
        big_angle(k) = angle23(i);
        %grand angle
        distance2(k) = d*sin((90-angle23(i))*pi/180)./(2*sin((30+angle23(i)-60)*pi/180));
        k = k+1;
    end
end

% plot the distance 
print('small angle does not work')
figure(2)
plot(small_angle,distance1)
figure(3)
plot(big_angle,distance2)

% %%timer 500khz
% delay12 = [0:2:580];
% delay23 = [0:2:580];

% angle12 = asin(delay12*(10^-6)*c/d)/pi*180;
% angle23 = asin(delay12*(10^-6)*c/d)/pi*180;
% figure(3)
% plot(delay12,angle12)

% distance = d*sin(angle23-30)/(2*sin(angle12-angle23+60));


% %%timer 250khz
% delay12 = [0:4:580];
% delay23 = [0:4:580];

% angle12 = asin(delay12*(10^-6)*c/d)/pi*180;
% angle23 = asin(delay12*(10^-6)*c/d)/pi*180;
% figure(3)
% plot(delay12,angle12)

% distance = d*sin(angle23-30)/(2*sin(angle12-angle23+60));