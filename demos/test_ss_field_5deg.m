% Jan. 21, 2022, implement nmo correction
% Yunfeng Chen, Global Seismology Group, Zhejiang University
% 
% Reference: Oboue Y.A.S.I, Y. Chen, J. Wang, X. Jiang, Ramin M.H. Dokht, Y. J. Gu, M. Koroni, and
% Y. Chen, 2023, High-resolution mantle transition zone imaging using
% multi-dimensional reconstruction of SS precursors, JGR, submitted 

clear; close all; clc;
%% Read in data and calculate bounce point (midpoint)
addpath('../rdrr')
addpath('../data') 
addpath('../etopo1_bed_c_f4') 
javaaddpath('./FMI/lib/FMI.jar');
addpath('~/MATLAB/m_map');
addpath('../Meier_2009') 
addpath('../plot_tectonic_fold_maps') 
addpath('../slab')
addpath('../MatSAC');
addpath('../utils');
addpath('../subroutines');
addpath('./FMI/matTaup');
addpath('../TX2019slab')
addpath('../irisFetch-matlab-2.0.12')
addpath export_fig
% load the data
% datadir = '/Users/yunfeng/30_40/publication/oboue/western_pacific/data/*';
% datadir = '/Users/oboue/Desktop/ssp/sspfield/western_pacific/data/*';
% event = dir(datadir);
% event(1:3)=[];
% nevt = length(event);
% ss=[];
% for i = 1:nevt
%     if mod(i,100) == 0
%         disp(['Reading ',num2str(i),'/',num2str(nevt),' events']);
%     end
%     sacfiles=dir(fullfile(event(i).folder,event(i).name,'*.T'));
%     for j = 1:length(sacfiles)
%         [t,data,SAChdr] = fget_sac(fullfile(sacfiles(j).folder,sacfiles(j).name));
%         tmp.d = data;
%         tmp.t = t;
%         tmp.stla=SAChdr.station.stla;
%         tmp.stlo=SAChdr.station.stlo;
%         tmp.stel=SAChdr.station.stel;
%         tmp.sta =SAChdr.station.kstnm;
%         tmp.evla=SAChdr.event.evla;
%         tmp.evlo=SAChdr.event.evlo;
%         tmp.evdp=SAChdr.event.evdp/1000.; % meter to kilometer
%         tmp.mag=SAChdr.event.mag;
%         tmp.dist=SAChdr.evsta.dist;
%         tmp.az=SAChdr.evsta.az;
%         tmp.baz=SAChdr.evsta.baz;
%         tmp.gcarc=SAChdr.evsta.gcarc;
%         % calculate the bounce point (midpoint)
%         [tmp.bplat,tmp.bplon]=gc_midpoint(tmp.evla, tmp.evlo, tmp.stla, tmp.stlo);
%         % calculate SS arrival time
%         times=taupTime('prem',tmp.evdp,'SS,S^410S,S^660S','sta',[tmp.stla tmp.stlo],...
%             'evt',[tmp.evla,tmp.evlo]);
%         tmp.t660=times(1).time;
%         tmp.t410=times(2).time;
%         tmp.tss=times(3).time;
%         ss=[ss tmp];
%     end
% end
% 
% % save as mat
% % save 'ss.mat' 'ss';

load ss_field.mat

figure;
plot([ss.bplon],[ss.bplat],'.')
k=2;
figure;
plot(ss(k).t,ss(k).d/max(ss(k).d)); hold on;
plot([ss(k).t410,ss(k).t410],[-1,1],'--r');
plot([ss(k).t660,ss(k).t660],[-1,1],'--r');
plot([ss(k).tss,ss(k).tss],[-1,1],'--r');
% calculate SNR
for k=1:length(ss)
    d=ss(k).d;
    t=ss(k).t;
    tss=ss(k).tss;
    ss(k).snr = ss_snr(d,t,tss);
end
% check polarity reversal
for k=1:length(ss)
    d=ss(k).d;
    t=ss(k).t;
    tss=ss(k).tss;
    [d,is_reversal] = ss_check_polarity(d,t,tss);
    ss(k).is_reversal = is_reversal;
    if is_reversal
        ss(k).d = d;
    end
end
remove = [ss.snr]<=5;
ss(remove) = [];
% apply cross-correlation to all traces
nt=length(t);
for k=1:length(ss)
    ss(k).d=ss(k).d(1:nt);
end
din = [ss.d]; % flatten the tensor
N=5; % number of iteration for cross-correlation measurments
t=0:nt-1;
times = repmat(t(:),1,size(din,2));
t0=ones(1,size(din,2))*900; % SS arrival
xwin=[-100 100]; % cross-correlation window
maxlag=50; % maximum time lag
is_plot=0; % flag controls plotting
dout = ss_align_v2(din,times,N,t0,xwin,maxlag,is_plot);
for k=1:length(ss)
    ss(k).d=dout(:,k);
end
%% Binning
dx=5; dy=5; dh=2;

xmin=110; ymin=20; hmin=100;
xmax=160; ymax=60; hmax=170;
% define grid center
x = xmin+dx/2:dx:xmax;
y = ymin+dy/2:dy:ymax;
h = hmin+dh/2:dh:hmax;
t = ss(1).t;

% dx=2.5; dy=2.5; dh=2;
% xmin=110; ymin=20; hmin=100;
% xmax=160; ymax=60; hmax=170;
lonlim=[xmin xmax];
latlim=[ymin ymax];
% define grid center
% x = xmin+dx/2:dx:xmax;
% y = ymin+dy/2:dy:ymax;
% h = hmin+dh/2:dh:hmax;
% t = ss(1).t;
% nx=length(x); ny=length(y); nh=length(h); nt = length(t);
% disp('Binning')

nx=length(x); ny=length(y); nh=length(h); nt = length(t);
disp('Binning')
% 5D case
% d1=zeros(nt, nx, ny, nh, nphi);
% 4D case
d1 = zeros(nt, nx, ny, nh);
fold_map=zeros(nx,ny,nh);
flow=1/75.;
fhigh=1/15.;
for n=1:length(ss)
    j=floor((ss(n).bplat-ymin)/dy)+1;
    i=floor((ss(n).bplon-xmin)/dx)+1;
    k=floor((ss(n).gcarc-hmin)/dh)+1;
%   l=floor(ss(n).phi/dphi)+1;
    fold_map(i,j,k)=fold_map(i,j,k)+1;
    d=ss(n).d;
    % bandpass filter
    d_filt=bandpassSeis(d,1,flow,fhigh,3);
    d_filt=d_filt/max(d_filt);
    d1(:,i,j,k)=d1(:,i,j,k)+d_filt(1:nt);
end
% nomalization
for i=1:nx
    for j=1:ny
        for k=1:nh
            if fold_map(i,j,k)>0
               d1(:,i,j,k)=d1(:,i,j,k)/fold_map(i,j,k); 
            end
        end
    end
end

% plot fold map
fold_map_xy=sum(fold_map,3);
figure;
set(gcf,'Position',[100 100 1000 800],'color','w')
imagesc(x,y,fold_map_xy'); hold on;
cm=colormap('gray');
colormap(flipud(cm));
colorbar;
axis tight;
plot([ss.bplon],[ss.bplat],'b.'); 
xlabel('Longitude (deg)');
ylabel('Latitude (deg)');
colorbar;
set(gca,'fontsize',14)
axis equal;
%% stack the CMP bin 
addpath m_map;

fold_map_xy=sum(fold_map,3);
figure;
set(gcf,'Position',[100 100 1600 800],'color','w')
subplot(121)
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w');
[X,Y]=meshgrid(x,y);
hs=m_scatter([ss.bplon],[ss.bplat],5,'b','filled');
alpha(hs,0.5);
m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',24);
text(-0.12,0.98,'(a)','Units','normalized','FontSize',32)
title('Bounce points','fontsize',30)

subplot(122)
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
[X,Y]=meshgrid(x,y);
hh=m_pcolor(X,Y,fold_map_xy');
set(hh,'edgecolor','none')
cm=colormap('gray');
colormap(flipud(cm));
caxis([0 300])
m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',24);
hh=colorbar('h');
set(hh,'fontsize',24);
set(hh,'Position',[0.6 0.1256 0.3 0.0250])
xlabel(hh,'Count');
text(-0.12,0.98,'(b)','Units','normalized','FontSize',32)
% export_fig(gcf,'fold_map.png','-q300')
title('Fold map','fontsize',30)
%
for n=1:nh
    times=taupTime('ak135',10,'SS,S^410S,S^660S','deg',h(n));
    indices = find(strcmp({times.phaseName},'S^660S'));
    t660(n)=times(indices(1)).time;
    indices = find(strcmp({times.phaseName},'S^410S'));
    t410(n)=times(indices(1)).time;
    indices = find(strcmp({times.phaseName},'SS'));
    tss(n)=times(indices(1)).time;
end
%%

d2dssp = squeeze(mean(mean(d1,3),2)); % simple averaging
W = any(d1);    % obtain the non-zero trace=
w = squeeze(sum(sum(W,3),2));  % calcualte the weight
d2d_w = squeeze(sum(sum(d1,3),2))*diag(1./w); % weighted averaging
size(d1)
size(d2dssp)
% find the time of SS phase and set it to 0 time
[~,index] = max(sum(d2dssp,2));
tshift = t(index);
t=t-tshift;
% %%
size(fold_map)
ntraces = squeeze(sum(sum(fold_map,2),1));
size(ntraces)
%%
% conduct NMO correction with a simple time-shift method
d2dssp_nmo=zeros(size(d2dssp));
h0=135;
is_plot=false;
for n=1:nh
    din = d2dssp(:,n);
    [dout,t410_ref,t660_ref] = ss_nmo(din,t,h(n),h0,is_plot);
    d2dssp_nmo(:,n)=dout;
end
%%
% size(d2dssp_nmo);
% figure;
% subplot(511)
% % bar(h,ntraces)
% subplot(5,1,2:5)
% set(gcf,'Position',[0 0 1000 1000],'Color','w')
% wigb(d2dssp,10,h,t);
% plot(h,ones(1,nh)*t410_ref,'--r')
% plot(h,ones(1,nh)*t660_ref,'--r')
% axis xy
% ylim([-450 50])
% ylabel('Time (s)')
% xlabel('Distance (deg)')
% set(gca,'fontsize',14)
% 
% size(d2dssp_nmo)
% figure;
% subplot(511)
% % bar(h,ntraces)
% subplot(5,1,2:5)
% set(gcf,'Position',[0 0 1000 1000],'Color','w')
% wigb(d2dssp_nmo,10,h,t);
% plot(h,ones(1,nh)*t410_ref,'--r')
% plot(h,ones(1,nh)*t660_ref,'--r')
% axis xy
% ylim([-450 50])
% ylabel('Time (s)')
% xlabel('Distance (deg)')
% set(gca,'fontsize',14)

% compare the stacked trace
% figure;
% plot(t,sum(d2d,2)); hold on;
% plot(t,sum(d2d_nmo,2));
% apply NMO correction to all traces
d1_nmo=zeros(size(d1));
h0=135;
is_plot=false;
%%
% parfor i=1:nx
for i=1:nx;
    for j=1:ny
        for k=1:nh
            din = d1(:,i,j,k);
            if any(d)
                dout = ss_nmo(din,t,h(k),h0,is_plot);
                d1_nmo(:,i,j,k)=dout;
            end
        end
    end
end

% q=size(d3Dnxnynh15)
%                d3Dnxnynh15noNMO=d1(:,:,:,15);
% %                d3Dnxnynh15=d1_nmo(:,:,:,15);   
%                
%                d3Dnxnynh1=d1_nmo(:,:,:,1);   
% perform stacking for each CMP gather
d3d_nmo = zeros(nt,nx,ny);
d3d = zeros(nt,nx,ny);
for i=1:nx
    for j=1:ny
        % move-out corrected cmp
        d_cmp = squeeze(d1_nmo(:,i,j,:));
        nstack = sum(any(d_cmp));
        if nstack>0
            d_stack = sum(d_cmp,2)/nstack;
            d3d_nmo(:,i,j)=d_stack;
        end
        % non-move-out corrected cmp
        d_cmp = squeeze(d1(:,i,j,:));
        nstack = sum(any(d_cmp));
        if nstack>0
            d_stack = sum(d_cmp,2)/nstack;
            d3d(:,i,j)=d_stack;
        end
    end
end
%% 3D post-stack reconstruction using RDRR algorithm
t0=-300;
t1=-100;
%t0=-500;
%t1=100;
keep = t>=t0 & t<=t1;
ss3d_nmo = d3d_nmo(keep,:,:);
[nt,nx,ny]=size(ss3d_nmo);
%
mask = repmat(any(ss3d_nmo),size(ss3d_nmo,1),1);

d03d=ss3d_nmo.*mask;
u=size(d03d);
dt=1;
flow=1/75;
fhigh=1/15.;
Niter=10;
mode=1;
verb=1;
a=(Niter-(1:Niter))/(Niter-1) %linearly decreasing

N=5; % Rank 
K=2;  % Damping factor
u=0.005; % Cooling factor 
e=0.9;     % Rational transfer function coefficient 
ws=1;      % Window size
%%
d3=fxyrdrr3d_denoising_recon(d03d,mask,flow,fhigh,dt,N,K,Niter,eps,verb,mode,a,u,e,ws);

%% 4D reconstruction using RDRR algorithm
ss4d_nmo = d1_nmo(keep,:,:,:);
[nt,nx,ny,nh]=size(ss4d_nmo);
% o=size(ss3d_nmo)
mask = repmat(any(ss4d_nmo),size(ss4d_nmo,1),1);%
d04d=ss4d_nmo.*mask;
flow=1/75;
fhigh=1/15.;

N=200; % Rank 
% N=5;
K=2;  % Damping factor
u=0.0001; % Cooling factor
e=0.80;  % Rational transfer function coefficient 
ws=1;    % Window size
iflb=0;
%
d4d=rdrr5d_lb_recon(d04d,mask,flow,fhigh,dt,N,K,Niter,eps,verb,mode,iflb,a,u,e,ws);
% save d4dfield_recon_srn3_r35K3u0001e080_2.5deg.mat d04d d4d nx ny nh keep t 

N=5;

d4d2=rdrr5d_lb_recon(d04d,mask,flow,fhigh,dt,N,K,Niter,eps,verb,mode,iflb,a,u,e,ws);

% size(d4d);
% save d2dssp_nmo.mat d2dssp_nmo t660_ref t410_ref d2d_w t410 t660 t nx ny nh keep h dx dy dh
% save d2dssp.mat d2dssp t660_ref t410_ref d2d_w t410 t660 t nx ny nh keep h dx dy dh
% %%
% save d4dfield_recon_stack_srn3_r35K3u0001e080_2.5deg.mat d0s d1rs nx ny nh keep t 
% plot figures pre-stack raw and reconstructed 

figure('units','normalized','Position',[0.0 0.0 1, 1],'color','w'); hold on
subplot(2,1,1);
imagesc(1:nx*ny*nh,t(keep),reshape(d04d,nt,nx*ny*nh)); hold on;
plot(1:nx*ny*nh,t410_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
plot(1:nx*ny*nh,t660_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
title('Pre-stack (Raw)')
text(-150,-90,'(a)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
colormap(seis);caxis([-0.07 0.07]);colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',20)
annotation(gcf,'textbox',...
    [0.833888888888889 0.827134658608409 0.0394444444444438 0.0320962888665998],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.836111111111111 0.70058325489185 0.0388888888888894 0.0320962888665998],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);

subplot(2,1,2);
imagesc(1:nx*ny*nh,t(keep),reshape(d4d,nt,nx*ny*nh)); hold on;
plot(1:nx*ny*nh,t410_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
plot(1:nx*ny*nh,t660_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
title('Pre-stack (Reconstructed)')
colormap(seis);caxis([-0.07 0.07]);colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',20)
text(-150,-90,'(b)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.836111111111112 0.356037139501707 0.0394444444444438 0.0260260260260258],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.836666666666666 0.22869621590094 0.0388888888888894 0.0275019251950038],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
%%

figure('units','normalized','Position',[0.0 0.0 1, 1],'color','w'); hold on
subplot(3,1,1);
imagesc(1:nx*ny*nh,t(keep),reshape(d04d,nt,nx*ny*nh)); hold on;
plot(1:nx*ny*nh,t410_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
plot(1:nx*ny*nh,t660_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
title('Pre-stack (Raw)')
colormap(seis);caxis([-0.07 0.07]);colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',20)
text(-150,-90,'(a)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.832777777777778 0.865520485380063 0.0394444444444438 0.0320962888665998],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.836111111111111 0.787197428120196 0.0388888888888894 0.0320962888665998],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);

subplot(3,1,2);
imagesc(1:nx*ny*nh,t(keep),reshape(d4d2,nt,nx*ny*nh)); hold on;
plot(1:nx*ny*nh,t410_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
plot(1:nx*ny*nh,t660_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
title('Pre-stack (Reconstructed)')
colormap(seis);caxis([-0.08 0.08]);colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',20)
text(-150,-90,'(b)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.835000000000001 0.572572572572573 0.0394444444444438 0.0260260260260259],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.838888888888888 0.491491491491491 0.0388888888888894 0.0275019251950038],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);

subplot(3,1,3);
set(gcf,'Position',[100 100 1600 500],'color','w')
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny*nh,t(keep),reshape(d4d,nt,nx*ny*nh)); hold on;
plot(1:nx*ny*nh,t410_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
plot(1:nx*ny*nh,t660_ref*ones(1,nx*ny*nh),'--r','linewidth',4)
title('Pre-stack (Reconstructed)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',20)
text(-150,-90,'(c)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.836666666666667 0.269269269269269 0.0394444444444438 0.026026026026026],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.838333333333333 0.19019019019019 0.037777777777778 0.0290305078859082],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',20,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
%% stacking process
% post-stack (raw)

d04ds = zeros(nt,nx,ny);
for i=1:nx
    for j=1:ny
%         move-out corrected cmp
        d4D_cmp_raw= squeeze(d04d(:,i,j,:));
        nstack = sum(any(d4D_cmp_raw));
        if nstack>0
            d_raw_stack = sum(d4D_cmp_raw,2)/nstack;
            d04ds(:,i,j)=d_raw_stack;
        end
    end 
end

% post-stack (reconstructed)

d4drs = zeros(nt,nx,ny);
for i=1:nx
    for j=1:ny
%         move-out corrected cmp
        d4D_cmp_recon = squeeze(d4d(:,i,j,:));
        nstack = sum(any(d4D_cmp_recon));
        if nstack>0
            d_recon_stack = sum(d4D_cmp_recon,2)/nstack;
            d4drs(:,i,j)=d_recon_stack;
        end
    end 
end

d4drs2 = zeros(nt,nx,ny);
for i=1:nx
    for j=1:ny
%         move-out corrected cmp
        d4D_cmp_recon2 = squeeze(d4d2(:,i,j,:));
        nstack = sum(any(d4D_cmp_recon2));
        if nstack>0
            d_recon_stack2 = sum(d4D_cmp_recon2,2)/nstack;
            d4drs2(:,i,j)=d_recon_stack2;
        end
    end 
end
%% plot figures post-stack raw and reconstructed 

figure('units','normalized','Position',[0.0 0.0 1 1],'color','w'); hold on
subplot(2,1,1);
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny,t(keep),reshape(d04ds,nt,nx*ny)); hold on;
plot(1:nx*ny,t410_ref*ones(1,nx*ny),'--r','linewidth',4)
plot(1:nx*ny,t660_ref*ones(1,nx*ny),'--r','linewidth',4)
title('Post-stack (Raw)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',16)
text(-3,-90,'(a)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.841666666666668 0.830899161798323 0.0299999999999995 0.0226780951328934],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.841666666666666 0.702620967741935 0.0305555555555556 0.0240171715936299],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);

subplot(2,1,2);
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny,t(keep),reshape(d4drs,nt,nx*ny)); hold on;
plot(1:nx*ny,t410_ref*ones(1,nx*ny),'--r','linewidth',4)
plot(1:nx*ny,t660_ref*ones(1,nx*ny),'--r','linewidth',4)
title('Post-stack (Reconstructed)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',16)
text(-3,-90,'(b)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.841666666666667 0.355779902023982 0.0299999999999995 0.0226780951328934],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.841111111111111 0.226515421560106 0.0305555555555556 0.02401717159363],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
%%
figure('units','normalized','Position',[0.0 0.0 1 1],'color','w'); hold on
subplot(4,1,1);
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny,t(keep),reshape(d04ds,nt,nx*ny)); hold on;
plot(1:nx*ny,t410_ref*ones(1,nx*ny),'--r','linewidth',4)
plot(1:nx*ny,t660_ref*ones(1,nx*ny),'--r','linewidth',4)
title('Post-stack (Raw)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',16)
text(-4,-90,'(a)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.842777777777779 0.880778511557022 0.0299999999999995 0.0226780951328934],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.841666666666666 0.82636684023368 0.0305555555555556 0.0240171715936299],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);

subplot(4,1,2);
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny,t(keep),reshape(d3,nt,nx*ny)); hold on;
plot(1:nx*ny,t410_ref*ones(1,nx*ny),'--r','linewidth',4)
plot(1:nx*ny,t660_ref*ones(1,nx*ny),'--r','linewidth',4)
title('Post-stack (Reconstructed 3D)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',16)
text(-4,-90,'(b)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.842222222222223 0.661290322580644 0.0299999999999995 0.0226780951328934],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.842222222222222 0.607862903225806 0.0305555555555556 0.0240171715936299],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
subplot(4,1,3);
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny,t(keep),reshape(d4drs2,nt,nx*ny)); hold on;
plot(1:nx*ny,t410_ref*ones(1,nx*ny),'--r','linewidth',4)
plot(1:nx*ny,t660_ref*ones(1,nx*ny),'--r','linewidth',4)
title('Post-stack (4D reconstruction using rank 5)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',16)
text(-4,-90,'(c)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.843888888888889 0.44534683115784 0.0299999999999995 0.0226780951328934],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.842777777777778 0.38990124833176 0.0305555555555556 0.02401717159363],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);

subplot(4,1,4);
set(gcf,'Position',[100 100 1600 500],'color','w')
imagesc(1:nx*ny,t(keep),reshape(d4drs,nt,nx*ny)); hold on;
plot(1:nx*ny,t410_ref*ones(1,nx*ny),'--r','linewidth',4)
plot(1:nx*ny,t660_ref*ones(1,nx*ny),'--r','linewidth',4)
title('Post-stack (4D reconstruction using rank 200)')
colormap(seis);caxis([-0.08 0.08]); colorbar;
axis xy
% xlim([1 80])
ylim([-300 -100])
ylabel('Time to SS (sec)')
xlabel('Trace');
set(gca,'fontsize',16)
text(-4,-90,'(d)','color','k','Fontsize',22,'fontweight','normal','HorizontalAlignment','center');
annotation(gcf,'textbox',...
    [0.842777777777778 0.224357931056932 0.0299999999999995 0.0226780951328935],...
    'String','S410S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
annotation(gcf,'textbox',...
    [0.841666666666667 0.170930511702093 0.0305555555555556 0.0240171715936301],...
    'String','S660S',...
    'FontWeight','bold',...
    'FontSize',16,...
    'FontName','Helvetica Neue',...
    'FitBoxToText','off',...
    'EdgeColor','none',...
    'BackgroundColor',[1 1 1]);
%% Time to depth conversion
dist = 95:5:170;
depth = 0:5:1000; 
[tt, f]=ss_tt_table(dist,depth);
z0=0:1:1000; 
h0=135;
x0=h0*ones(size(z0));
t0=f(x0,z0);

keep = t>=-300 & t<=-100;

t=t(keep);
ti=t;
% t0=-300;
% t1=-100;
% %t0=-500;
% %t1=100;
% keep = t>=t0 & t<=t1;

nz=length(z0);
d3d0_depth=zeros(nz,nx,ny);
d3d1_depth=zeros(nz,nx,ny);
d3d2_depth=zeros(nz,nx,ny);
% d3d3_depth=zeros(nz,nx,ny);

for i = 1:nx
    for j = 1:ny
        d=d04ds(:,i,j);
        dtmp=interp1(ti,d,t0,'linear',0);
        d3d0_depth(:,i,j)=dtmp;
        
        d=d3(:,i,j);
        dtmp=interp1(ti,d,t0,'linear',0);
        d3d1_depth(:,i,j)=dtmp;
        
        d=d4drs2(:,i,j);
        dtmp=interp1(ti,d,t0,'linear',0);
        d3d2_depth(:,i,j)=dtmp;

        d=d4drs(:,i,j);
        dtmp=interp1(ti,d,t0,'linear',0);
        d3d3_depth(:,i,j)=dtmp;
    end
end

%plot the trace in depth domain
d2d0_depth=reshape(d3d0_depth,nz,nx*ny);
d2d1_depth=reshape(d3d1_depth,nz,nx*ny);
d2d2_depth=reshape(d3d2_depth,nz,nx*ny);
d2d3_depth=reshape(d3d3_depth,nz,nx*ny);
%% find the maximum amplitude in the given depth intervals
depth0=z0;
drange1=[390,430];
drange2=[640,680];
drange3=[500,540];
% 
amp410_d0=zeros(nx,ny);
amp520_d0=zeros(nx,ny);
amp660_d0=zeros(nx,ny);
d410_d0=zeros(nx,ny);
d520_d0=zeros(nx,ny);
d660_d0=zeros(nx,ny);

amp410_d1=zeros(nx,ny);
amp520_d1=zeros(nx,ny);
amp660_d1=zeros(nx,ny);
d410_d1=zeros(nx,ny);
d520_d1=zeros(nx,ny);
d660_d1=zeros(nx,ny);
% 
amp410_d2=zeros(nx,ny);
amp520_d2=zeros(nx,ny);
amp660_d2=zeros(nx,ny);
d410_d2=zeros(nx,ny);
d520_d2=zeros(nx,ny);
d660_d2=zeros(nx,ny);
% 
amp410_d3=zeros(nx,ny);
amp520_d3=zeros(nx,ny);
amp660_d3=zeros(nx,ny);
d410_d3=zeros(nx,ny);
d520_d3=zeros(nx,ny);
d660_d3=zeros(nx,ny);
% 
for i=1:nx
    for j=1:ny
        d0=squeeze(d3d0_depth(:,i,j));
        keep1=find(depth0>=drange1(1) & depth0<=drange1(2));
        keep2=find(depth0>=drange2(1) & depth0<=drange2(2));
        keep3=find(depth0>=drange3(1) & depth0<=drange3(2));
        % find the maximum amplitude
        [amp410_d0(i,j),i1]=max(d0(keep1));
        [amp660_d0(i,j),i2]=max(d0(keep2));
        [amp520_d0(i,j),i3]=max(d0(keep3));
        ind410=keep1(i1);
        ind660=keep2(i2);
        ind520=keep3(i3);
        d410_d0(i,j)=depth0(ind410);
        d660_d0(i,j)=depth0(ind660);
        d520_d0(i,j)=depth0(ind520);

        d0=squeeze(d3d1_depth(:,i,j));
        % find the maximum amplitude
        [amp410_d1(i,j),i1]=max(d0(keep1));
        [amp660_d1(i,j),i2]=max(d0(keep2));
        [amp520_d1(i,j),i3]=max(d0(keep3));
        ind410=keep1(i1);
        ind660=keep2(i2);
        ind520=keep3(i3);
        d410_d1(i,j)=depth0(ind410);
        d660_d1(i,j)=depth0(ind660);
        d520_d1(i,j)=depth0(ind520);

        d0=squeeze(d3d2_depth(:,i,j));
        % find the maximum amplitude
        [amp410_d2(i,j),i1]=max(d0(keep1));
        [amp660_d2(i,j),i2]=max(d0(keep2));
        [amp520_d2(i,j),i3]=max(d0(keep3));
        ind410=keep1(i1);
        ind660=keep2(i2);
        ind520=keep3(i3);
        d410_d2(i,j)=depth0(ind410);
        d660_d2(i,j)=depth0(ind660);
        d520_d2(i,j)=depth0(ind520);

        d0=squeeze(d3d3_depth(:,i,j));
        % find the maximum amplitude
        [amp410_d3(i,j),i1]=max(d0(keep1));
        [amp660_d3(i,j),i2]=max(d0(keep2));
        [amp520_d3(i,j),i3]=max(d0(keep3));
        ind410=keep1(i1);
        ind660=keep2(i2);
        ind520=keep3(i3);
        d410_d3(i,j)=depth0(ind410);
        d660_d3(i,j)=depth0(ind660);
        d520_d3(i,j)=depth0(ind520);
    end
end

d410_d0=d410_d0';
d520_d0=d520_d0';
d660_d0=d660_d0';

d410_d1=d410_d1';
d520_d1=d520_d1';
d660_d1=d660_d1';
% 
d410_d2=d410_d2';
d520_d2=d520_d2';
d660_d2=d660_d2';
% 
d410_d3=d410_d3';
d520_d3=d520_d3';
d660_d3=d660_d3';
%% plot 410
dx=5; dy=5; dh=2;
xmin=110; ymin=20; hmin=100;
xmax=160; ymax=60; hmax=170;
% define grid center
x = xmin+dx/2:dx:xmax;
y = ymin+dy/2:dy:ymax;
h = hmin+dh/2:dh:hmax;

lonlim=[xmin xmax];
latlim=[ymin ymax];

[Xgrid,Ygrid]=meshgrid(x,y);

% save the model
% results=[Xgrid(:) Ygrid(:) d410_d0(:) d660_d0(:)];

Vgrid_d0=d410_d0;
F410_d0=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d0(:),'natural','none');
Vgrid_d1=d410_d1;
F410_d1=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d1(:),'natural','none');
Vgrid_d2=d410_d2;
F410_d2=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d2(:),'natural','none');
Vgrid_d3=d410_d3;
F410_d3=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d3(:),'natural','none');

xi=lonlim(1):0.2:lonlim(2);
yi=latlim(1):0.2:latlim(2);
[XI,YI]=meshgrid(xi,yi);
d410_d0_interp=F410_d0(XI,YI);
d410_d1_interp=F410_d1(XI,YI);
d410_d2_interp=F410_d2(XI,YI);
d410_d3_interp=F410_d3(XI,YI);

% smooth the results
% ngrid=floor(5/0.2);
ngrid=1;
K = (1/ngrid^2)*ones(ngrid,ngrid);
d410_d0_smooth = conv2(d410_d0_interp,K,'same');
d410_d1_smooth = conv2(d410_d1_interp,K,'same');
d410_d2_smooth = conv2(d410_d2_interp,K,'same');
d410_d3_smooth = conv2(d410_d3_interp,K,'same');

vmean=mean(d410_d1_smooth(~isnan(d410_d1_smooth)));

addpath 'm_map'

figure('units','normalized','Position',[0.0 0.0 1 1],'color','w'); hold on
subplot(2,2,1);
set(gcf,'Position',[100 100 1000 1000],'color','w')
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d410_d0_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([385 435])
% 
m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('MTZ 410 (Raw)','fontsize',18)
text(-0.16,0.98,'(a)','Units','normalized','FontSize',24)

subplot(2,2,2);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d410_d1_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([385 435])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('MTZ 410 (3D reconstruction)','fontsize',18)
text(-0.1,0.98,'(b)','Units','normalized','FontSize',24)
% 
subplot(2,2,3);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d410_d2_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([385 435])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('MTZ 410 (4D reconstruction, rank 5)','fontsize',18)
text(-0.16,0.98,'(c)','Units','normalized','FontSize',24)

subplot(2,2,4);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d410_d3_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([390 450])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
hh=colorbar('h');
set(hh,'fontsize',14);
set(hh,'Position',[0.3065 0.06 0.4220 0.0250])
xlabel(hh,'Depth (km)');
title('MTZ 410 (4D reconstruction, rank 200)','fontsize',18)
text(-0.16,0.98,'(d)','Units','normalized','FontSize',24)

% % save to GMT plot
% outdir='/home/bm/Desktop/sspGMT';
% outdir='/Users/oboue/Desktop/ssp/synth_ssp_New/SS-recon_v0new/sspGMT';
% results=[Xgrid(:),Ygrid(:),Vgrid_d0(:)];
% save(fullfile(outdir,'d410true.txt'),'results','-ascii');
% 
% results=[Xgrid(:),Ygrid(:),Vgrid_d1(:)];
% save(fullfile(outdir,'d410raw.txt'),'results','-ascii');
% 
% results=[Xgrid(:),Ygrid(:),Vgrid_d2(:)];
% save(fullfile(outdir,'d410rec.txt'),'results','-ascii');
%% plot 660
Vgrid_d0=d660_d0;
F660_d0=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d0(:),'natural','none');
Vgrid_d1=d660_d1;
F660_d1=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d1(:),'natural','none');
Vgrid_d2=d660_d2;
F660_d2=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d2(:),'natural','none');
Vgrid_d3=d660_d3;
F660_d3=scatteredInterpolant(Xgrid(:),Ygrid(:),Vgrid_d3(:),'natural','none');

xi=lonlim(1):0.2:lonlim(2);
yi=latlim(1):0.2:latlim(2);
[XI,YI]=meshgrid(xi,yi);
d660_d0_interp=F660_d0(XI,YI);
d660_d1_interp=F660_d1(XI,YI);
d660_d2_interp=F660_d2(XI,YI);
d660_d3_interp=F660_d3(XI,YI);

K = (1/ngrid^2)*ones(ngrid,ngrid);
d660_d0_smooth = conv2(d660_d0_interp,K,'same');
d660_d1_smooth = conv2(d660_d1_interp,K,'same');
d660_d2_smooth = conv2(d660_d2_interp,K,'same');
d660_d3_smooth = conv2(d660_d3_interp,K,'same');

vmean=mean(d660_d1_smooth(~isnan(d660_d1_smooth)));

figure('units','normalized','Position',[0.0 0.0 1 1],'color','w'); hold on
subplot(2,2,1);
set(gcf,'Position',[100 100 1000 1000],'color','w')
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d660_d0_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([630 690])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('MTZ 660 (Raw)','fontsize',18)
text(-0.16,0.98,'(a)','Units','normalized','FontSize',24)

subplot(2,2,2);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d660_d1_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([630 690])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('MTZ 660 (3D reconstruction)','fontsize',18)
text(-0.1,0.98,'(b)','Units','normalized','FontSize',24)

subplot(2,2,3);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d660_d2_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([630 690])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('MTZ 660 (4D reconstruction, rank 5)','fontsize',18)
text(-0.16,0.98,'(c)','Units','normalized','FontSize',24)

subplot(2,2,4);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,d660_d3_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
cm=colormap(jet);
colormap(flipud(cm));
caxis([630 690])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
hh=colorbar('h');
set(hh,'fontsize',14);
set(hh,'Position',[0.3065 0.06 0.4220 0.0250])
xlabel(hh,'Depth (km)');
title('MTZ 660 (4D reconstruction, rank 200)','fontsize',18)
text(-0.16,0.98,'(d)','Units','normalized','FontSize',24)
% export_fig 'mtz_660.png' '-r150'
% % save to GMT plot
% outdir='/Users/yunfeng/30_40/publications/oboue/ss/figures/mtz_map';
% results=[Xgrid(:),Ygrid(:),Vgrid_d1(:)];
% save(fullfile(outdir,'d660.txt'),'results','-ascii');

% outdir='//home/bm/Desktop/sspGMT';
% outdir='/Users/oboue/Desktop/ssp/synth_ssp_New/SS-recon_v0new/sspGMT';
% results=[Xgrid(:),Ygrid(:),Vgrid_d0(:)];
% save(fullfile(outdir,'d660true.txt'),'results','-ascii');
% 
% results=[Xgrid(:),Ygrid(:),Vgrid_d1(:)];
% save(fullfile(outdir,'d660raw.txt'),'results','-ascii');
% 
% results=[Xgrid(:),Ygrid(:),Vgrid_d2(:)];
% save(fullfile(outdir,'d660rec.txt'),'results','-ascii');
%% plot thickness of MTZ (660-410)

thi_d0=d660_d0_smooth-d410_d0_smooth;
thi_d1=d660_d1_smooth-d410_d1_smooth;
thi_d2=d660_d2_smooth-d410_d2_smooth;
thi_d3=d660_d3_smooth-d410_d3_smooth;
% 
ngrid=1;

K = (1/ngrid^2)*ones(ngrid,ngrid);
thi_d0_smooth = conv2(thi_d0,K,'same');
thi_d1_smooth = conv2(thi_d1,K,'same');
thi_d2_smooth = conv2(thi_d2,K,'same');
thi_d3_smooth = conv2(thi_d3,K,'same');
vmean=mean(thi_d1_smooth(~isnan(thi_d1_smooth)));

figure('units','normalized','Position',[0.0 0.0 1 1],'color','w'); hold on
subplot(2,2,1);
set(gcf,'Position',[100 100 1000 1000],'color','w')
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,thi_d0_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([vmean-10 vmean+10])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('Thickness (Raw)','fontsize',18)
text(-0.16,0.98,'(a)','Units','normalized','FontSize',24)

subplot(2,2,2);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,thi_d1_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([vmean-10 vmean+10])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('Thickness (3D reconstruction)','fontsize',18)
text(-0.1,0.98,'(b)','Units','normalized','FontSize',24)

subplot(2,2,3);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,thi_d2_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([vmean-10 vmean+10])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
title('Thickness (4D reconstruction, rank 5)','fontsize',18)
text(-0.16,0.98,'(c)','Units','normalized','FontSize',24)

subplot(2,2,4);
m_proj('lambert','long', lonlim, 'lat', latlim); hold on;
set(gcf,'color','w')
h=m_pcolor(XI,YI,thi_d3_smooth);
set(h,'edgecolor','none')
cm=colormap(jet);
colormap(flipud(cm));
caxis([vmean-10 vmean+10])

m_gshhs('i','line','color','k','linewidth',1)
m_gshhs('lb2','line','color','k')
m_grid('linewidth',2,'tickdir','out',...
    'xaxisloc','bottom','yaxisloc','left','fontsize',14);
hh=colorbar('h');
set(hh,'fontsize',14);
set(hh,'Position',[0.3065 0.06 0.4220 0.0250])
xlabel(hh,'Depth (km)');
title('Thickness (4D reconstruction, rank 200)','fontsize',18)
text(-0.16,0.98,'(d)','Units','normalized','FontSize',24)
