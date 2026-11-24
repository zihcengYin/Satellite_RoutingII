function fig = plot_constellation_2d(cfg, satellites, links, route, showInterPlane)
%PLOT_CONSTELLATION_2D Show satellite subpoints and ISLs on a lon/lat map.
%   Uses WGS84 geodetic coordinates converted from ECI at the snapshot UTC.
%   ISLs are drawn as map projections, not physical paths on Earth's surface.
%   An optional ROUTE from find_hop_min_path highlights its ISLs in red.
%   Inter-plane ISLs are orange and hidden by default. Pass true as the
%   fifth input to show them; the highlighted route stays visible.

    if nargin < 4
        route = [];
    end
    if nargin < 5 || isempty(showInterPlane)
        showInterPlane = false;
    end
    if ~isscalar(showInterPlane) || ...
            ~(islogical(showInterPlane) || isnumeric(showInterPlane)) || ...
            ~ismember(showInterPlane, [0,1])
        error('showInterPlane must be a logical scalar.');
    end

    location = satellite_lla_from_eci(cfg, satellites);
    lla = location.by_id;
    nodeCount = cfg.model.M * cfg.model.N;
    if numel(links.source_id) ~= numel(links.target_id) || ...
            numel(links.type) ~= numel(links.source_id) || ...
            any(links.source_id < 1) || any(links.target_id < 1) || ...
            any(links.source_id > nodeCount) || ...
            any(links.target_id > nodeCount)
        error('Link endpoints do not match the constellation.');
    end

    fig = figure('Name', sprintf('%s constellation 2D', cfg.model.name), ...
        'Color', 'w', 'Position', [100,100,1200,650]);
    ax = axes(fig);
    hold(ax, 'on');

    mapFile = fullfile(fileparts(mfilename('fullpath')), 'earth_0.jpg');
    if isfile(mapFile)
        image(ax, [-180,180], [90,-90], imread(mapFile));
        set(ax, 'YDir', 'normal');
    end

    hIntra = plot_link_type(ax, lla, links, "intra", [0.25,0.56,0.76]);
    hInter = plot_link_type(ax, lla, links, "inter", [0.95,0.49,0.10]);
    if ~showInterPlane
        hInter.Visible = 'off';
    end
    hSat = scatter(ax, lla(:,2), lla(:,1), 10, ...
        [0.05,0.20,0.52], 'filled');

    legendHandles = [hSat,hIntra];
    legendNames = {'Satellites','Intra-plane ISL'};
    if showInterPlane
        legendHandles = [legendHandles,hInter];
        legendNames = [legendNames,{'Inter-plane ISL'}];
    end
    if ~isempty(route)
        nodes = checked_route_nodes(route, links, nodeCount);
        hRoute = plot_segments(ax, lla, nodes(1:end-1), ...
            nodes(2:end), [0.88,0.05,0.07], 2.6);
        hSource = scatter(ax, lla(nodes(1),2), lla(nodes(1),1), ...
            85, [0.05,0.65,0.20], 'filled', 'MarkerEdgeColor', 'k');
        hTarget = scatter(ax, lla(nodes(end),2), lla(nodes(end),1), ...
            85, [0.64,0.14,0.70], 'filled', 'MarkerEdgeColor', 'k');
        legendHandles = [legendHandles,hRoute,hSource,hTarget];
        legendNames = [legendNames, ...
            {'Hop-min route','Source','Target'}];
    end

    axis(ax, 'equal');
    xlim(ax, [-180,180]);
    ylim(ax, [-90,90]);
    grid(ax, 'on');
    xlabel(ax, 'Longitude (deg)');
    ylabel(ax, 'Latitude (deg)');
    title(ax, sprintf('%s | M=%d, N=%d, F=%d | t=%g s', ...
        cfg.model.name, cfg.model.M, cfg.model.N, cfg.model.F, ...
        satellites.time_offset_s));
    legend(ax, legendHandles, legendNames, 'Location', 'bestoutside');
end

function h = plot_link_type(ax, lla, links, wantedType, color)
    rows = find(links.type == wantedType);
    h = plot_segments(ax, lla, links.source_id(rows), ...
        links.target_id(rows), color, 0.8);
end

function h = plot_segments(ax, lla, source, target, color, lineWidth)
    count = numel(source);
    x = nan(6*count,1);
    y = nan(6*count,1);
    cursor = 0;
    for k = 1:count
        a = source(k);
        b = target(k);
        lon1 = lla(a,2); lat1 = lla(a,1);
        lon2 = lla(b,2); lat2 = lla(b,1);
        gap = lon2-lon1;
        if abs(gap) <= 180
            x(cursor+(1:3)) = [lon1;lon2;NaN];
            y(cursor+(1:3)) = [lat1;lat2;NaN];
            cursor = cursor+3;
        else
            if gap > 180
                lon2Adjusted = lon2-360;
                border = -180;
                otherBorder = 180;
            else
                lon2Adjusted = lon2+360;
                border = 180;
                otherBorder = -180;
            end
            fraction = (border-lon1)/(lon2Adjusted-lon1);
            latBorder = lat1+fraction*(lat2-lat1);
            x(cursor+(1:6)) = [lon1;border;NaN;otherBorder;lon2;NaN];
            y(cursor+(1:6)) = [lat1;latBorder;NaN;latBorder;lat2;NaN];
            cursor = cursor+6;
        end
    end
    h = plot(ax, x(1:cursor), y(1:cursor), '-', ...
        'Color', color, 'LineWidth', lineWidth);
end

function nodes = checked_route_nodes(route, links, nodeCount)
    if ~isstruct(route) || ~isfield(route, 'node_ids')
        error('route must contain node_ids.');
    end
    nodes = route.node_ids(:);
    if isempty(nodes) || any(~isfinite(nodes)) || ...
            any(nodes ~= fix(nodes)) || ...
            any(nodes < 1) || any(nodes > nodeCount)
        error('route.node_ids contains invalid satellite IDs.');
    end
    pairs = sort([nodes(1:end-1), nodes(2:end)], 2);
    edges = sort([links.source_id(:), links.target_id(:)], 2);
    if ~all(ismember(pairs, edges, 'rows'))
        error('The highlighted route contains an edge absent from links.');
    end
end
