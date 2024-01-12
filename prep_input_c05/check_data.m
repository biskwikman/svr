%
% Check data
%


clear all;

infile='svr.test.FLX.GPP.201.txt';

% 1: year
% 2: doy
% 3: site id
% 4: crossval-id

din=csvread(infile);

dsite=din(:,3);
dcross=din(:,4);

duqid=unique(dsite);
duqcvid=unique(dcross);
nuqcvid=length(duqcvid);

for iid=1:nuqcvid
    
    ncvid(iid)=length(find(dcross(:)==duqcvid(iid)));
    
end


for iid=1:nuqcvid
    
    [duqcvid(iid) ncvid(iid)]
    
end

for iid=1:nuqcvid
    
    idx=find(dcross(:)==duqcvid(iid));
    ncuqsid=unique(dsite(idx))
    
end    









