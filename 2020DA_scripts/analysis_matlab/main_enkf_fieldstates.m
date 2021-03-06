function [] = main_enkf_fieldstates()
    clc
    clear
    close all
    dbstop if error
    format short g
    
    load('test_inform.mat')
    simul_dir = [simul_dir '/date1'];
    
    take_mean = 1;
    if take_mean==1
        ID = 1:Ne;
    else
        ID = 1; 
    end
%% % compare with CS2-SMOS, NOTE this dataset is from Oct.15 to April
    Var = 'sit';
    mnt_CS2SMOS_dir = '~/src/nextsim_data_dir/CS2_SMOS_v2.2';

    %% load **.nc.analysis
    it = 1;
    clear data data_tmp
    for ie = ID
        filename = [simul_dir '/filter/prior/mem' num2str(ie,'%03d') '.nc.analysis'];
        data_tmp = ncread(filename,Var); 
        data(ie,:,:) = data_tmp(:,:,it); %% change date index it =1
    end
    analysis_data = squeeze(mean(data,1));

    %% load **.nc 
    clear data data_tmp
    for ie = ID
        filename = [simul_dir '/filter/prior/mem' num2str(ie,'%03d') '.nc'];
        data_tmp = ncread(filename,Var); 
        data(ie,:,:) = data_tmp(:,:,it); 
    end
    forecast_data = squeeze(mean(data,1));
    lon = ncread(filename,'longitude');
    lat = ncread(filename,'latitude');
    %% load observation
    t = dates(it)+Duration;
    temp1 = strrep(datestr(t,26),'/','');
    temp2 = strrep(datestr(t+Duration-1,26),'/','');
    filename = [ mnt_CS2SMOS_dir '/W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_' temp1 '_' temp2 '_r_v202_01_l4sit.nc' ]
    data_obs = ncread(filename,'analysis_sea_ice_thickness');  
    % obs_data = ncread(filename,'sea_ice_concentration');
    lon_obs = ncread(filename,'lon');
    lat_obs = ncread(filename,'lat');
%%
    figure();
    set(gcf,'Position',[100,150,1100,850], 'color','w')
    unit = '(m)';
    subplot(221); fun_geo_plot(lon,lat,forecast_data,' background',unit); caxis([0 6]); colormap(gca,parula);
    subplot(222); fun_geo_plot(lon,lat,analysis_data,' analysis',unit); caxis([0 6]); colormap(gca,parula);
    subplot(223); fun_geo_plot(lon,lat,analysis_data-forecast_data,'analysis - background',unit);  %caxis([-2 2]); 
    colormap(gca,bluewhitered);
    subplot(224); fun_geo_plot(lon_obs,lat_obs, data_obs,['observation ' temp1],unit); %caxis([0 6]);
    colormap(gca,parula);
    set(findall(gcf,'-property','FontSize'),'FontSize',20); 
    %
    % filename = [ simul_dir '/filter/observations.nc'];
    % lon = ncread(filename,'lon'); 
    % lat = ncread(filename,'lat'); 
    % y     = ncread(filename,'value');  % observation value
    % Hx    = ncread(filename,'Hx_a');   % forecast(_f)/analysis(_a) observation (forecast observation ensemble mean)
    % std_o = ncread(filename,'std');    % standard deviation of observation error used in DA
    % std_e = ncread(filename,'std_a');  % standard deviation of the forecast(_f)/analysis(_a) observation ensemble
    if(take_mean==1)
        saveas(gcf,[ 'size' num2str(Ne) '_mean_' Var '_difference_main_CS2SMOS.png'],'png');
    else
        saveas(gcf,[ 'size' num2str(Ne) '_mem' num2str(ie) '_' Var '_difference_main_CS2SMOS.png'],'png');
    end
end

function fun_geo_plot(lon,lat,Var,Title, unit)
    Var(Var==0) = nan;
    m_proj('Stereographic','lon',-45,'lat',90,'radius',25);
    m_pcolor(lon, lat, Var); shading flat; 
    h = colorbar;
    title(h, unit);
    m_coast('patch',0.7*[1 1 1]);    
    set(gca,'XTickLabel',[],'YTickLabel',[]);
    title({Title,''})
    m_grid('linest',':');
end
