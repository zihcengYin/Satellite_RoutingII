function fig = plot_constellation_3d(cfg, satellites, links, route, showInterPlane)
%PLOT_CONSTELLATION_3D Plot Earth, satellites, and both ISL types in ECI.
%   FIG = PLOT_CONSTELLATION_3D(CFG, SATELLITES, LINKS) uses kilometre units.
%   An optional ROUTE from find_hop_min_path highlights its ISLs in red.
%   Inter-plane ISLs are hidden by default. Pass true as the fifth input
%   to show them.

    if nargin < 4
        route = [];
    end
    if nargin < 5 || isempty(showInterPlane)
        showInterPlane = false;
    end
    if ~isscalar(showInterPlane) || ...
            ~(islogical(showInterPlane) || isnumeric(showInterPlane)) || ...
            ~ismember(showInterPlane, [0, 1])
        error('showInterPlane must be a logical scalar.');
    end

    pos = satellites.position_eci_km;
    M = cfg.model.M;
    N = cfg.model.N;
    if ~isequal(size(pos), [M, N, 3]) || ...
            ~isfield(cfg, 'earth') || ~isfield(cfg.earth, 'radius_km')
        error('Satellite positions or Earth radius do not match cfg.');
    end
    xyz = reshape(permute(pos, [2,1,3]), [], 3); % m*n rows & 3(x, y, z) columes
    if any(links.source_id < 1) || any(links.target_id > M*N)
        error('Link endpoints are outside the constellation.');
    end

    fig = figure('Name', sprintf('%s constellation 3D', cfg.model.name), ...
        'Color', 'w', 'Position', [100,100,1200,800]);
    ax = axes(fig);
    hold(ax, 'on');

    earthRadius = cfg.earth.radius_km;
    textureFile = fullfile(fileparts(mfilename('fullpath')), 'earth_3.jpg');
    if isfile(textureFile)
        texture = imread(textureFile);
        % Keep every texture pixel. Surface mesh resolution is independent
        % of texture resolution when FaceColor is 'texturemap'.
        % Image rows run north-to-south; columns run west-to-east.
        latitude = linspace(90, -90, 65);
        longitude = linspace(-180, 180, 129);
        [lonGrid, latGrid] = meshgrid(longitude, latitude);
        earthX = earthRadius*cosd(latGrid).*cosd(lonGrid);
        earthY = earthRadius*cosd(latGrid).*sind(lonGrid);
        earthZ = earthRadius*sind(latGrid);
        hEarth = surf(ax, earthX, earthY, earthZ, texture, ...
            'FaceColor', 'texturemap', 'EdgeColor', 'none', ...
            'FaceAlpha', 1, 'DisplayName', 'Earth');
    else
        [ex, ey, ez] = sphere(48);
        hEarth = surf(ax, earthRadius*ex, earthRadius*ey, ...
            earthRadius*ez, 'FaceColor', [0.23, 0.46, 0.72], ...
            'EdgeColor', 'none', 'DisplayName', 'Earth');
    end

    hIntra = plot_type(ax, xyz, links, "intra", [0.25, 0.56, 0.76]);
    hInter = plot_type(ax, xyz, links, "inter", [0.95, 0.49, 0.10]);
    if ~showInterPlane
        hInter.Visible = 'off';
    end
    hSat = scatter3(ax, xyz(:,1), xyz(:,2), xyz(:,3), 10, ...
        [0.12, 0.12, 0.15], 'filled', 'DisplayName', 'Satellites');

    legendHandles = [hEarth, hSat, hIntra];
    legendNames = {'Earth', 'Satellites', 'Intra-plane ISL'};
    if showInterPlane
        legendHandles = [legendHandles, hInter];
        legendNames = [legendNames, {'Inter-plane ISL'}];
    end
    if ~isempty(route)
        nodes = checked_route_nodes(route, links, M*N);
        routeLabel = 'Hop-min route';
        if isfield(route, 'route_label') && ~isempty(route.route_label)
            routeLabel = char(route.route_label);
        end
        hRoute = plot3(ax, xyz(nodes,1), xyz(nodes,2), ...
            xyz(nodes,3), '-', 'Color', [0.88,0.05,0.07], ...
            'LineWidth', 3);
        hSource = scatter3(ax, xyz(nodes(1),1), xyz(nodes(1),2), ...
            xyz(nodes(1),3), 90, [0.05,0.65,0.20], 'filled', ...
            'MarkerEdgeColor', 'k');
        hTarget = scatter3(ax, xyz(nodes(end),1), xyz(nodes(end),2), ...
            xyz(nodes(end),3), 90, [0.64,0.14,0.70], 'filled', ...
            'MarkerEdgeColor', 'k');
        legendHandles = [legendHandles, hRoute, hSource, hTarget];
        legendNames = [legendNames, ...
            {routeLabel, 'Source', 'Target'}];
    end

    axis(ax, 'equal');
    axis(ax, 'tight');
    grid(ax, 'on');
    xlabel(ax, 'ECI x (km)');
    ylabel(ax, 'ECI y (km)');
    zlabel(ax, 'ECI z (km)');
    titleText = sprintf('%s | M=%d, N=%d, F=%d | t=%g s', ...
        cfg.model.name, M, N, cfg.model.F, satellites.time_offset_s);
    if ~isempty(route)
        titleText = sprintf('%s | %s', titleText, routeLabel);
        fig.Name = titleText;
    end
    title(ax, titleText);
    view(ax, 35, 25);
    % The source plot shows the texture without an added headlight. A
    % headlight creates a bright glare and darkens most map detail.
    hEarth.FaceLighting = 'none';
    legend(ax, legendHandles, legendNames, 'Location', 'northeast');
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

function h = plot_type(ax, xyz, links, wantedType, color)
    rows = find(links.type == wantedType);
    count = numel(rows);
    x = nan(3*count,1);
    y = nan(3*count,1);
    z = nan(3*count,1);
    for k = 1:count
        a = links.source_id(rows(k));
        b = links.target_id(rows(k));
        at = 3*k-2;
        x(at:at+1) = [xyz(a,1); xyz(b,1)];
        y(at:at+1) = [xyz(a,2); xyz(b,2)];
        z(at:at+1) = [xyz(a,3); xyz(b,3)];
    end
    h = plot3(ax, x, y, z, '-', 'Color', color, 'LineWidth', 0.7);
end
