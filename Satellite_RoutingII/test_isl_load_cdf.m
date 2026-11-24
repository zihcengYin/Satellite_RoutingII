function result = test_isl_load_cdf(numFlows, profileName, modelName)
%TEST_ISL_LOAD_CDF Compare routing load and propagation delay with four CDFs.
%   TEST_ISL_LOAD_CDF() uses 1000 uniformly sampled satellite pairs in
%   ppt/Design at one constellation snapshot. All three algorithms
%   receive the same pairs: global Dijkstra, deterministic high-latitude,
%   and latitude-weighted random routing with alpha = 100 per degree.
%   The first three CDFs weight each ISL's absolute mean endpoint latitude
%   by its number of path traversals. They are NOT CDFs of load magnitudes.
%   The last CDF uses one propagation delay per source-target pair.
%
%   RESULT = TEST_ISL_LOAD_CDF(NUMFLOWS, PROFILENAME, MODELNAME) accepts
%   'routing' or 'ppt' and any model supported by its config function.
%   This satellite-to-satellite experiment has no ground-link delay,
%   queuing delay, or capacity model. The saved RNG state is restored.

    if nargin < 1 || isempty(numFlows)
        numFlows = 1000;
    end
    if nargin < 2 || isempty(profileName)
        profileName = 'ppt';
    end
    if nargin < 3 || isempty(modelName)
        modelName = 'Design';
    end
    if ~isscalar(numFlows) || ~isnumeric(numFlows) || ...
            ~isfinite(numFlows) || numFlows < 1 || ...
            numFlows ~= fix(numFlows)
        error('numFlows must be a positive integer.');
    end
    if ~(ischar(profileName) || (isstring(profileName) && isscalar(profileName)))
        error('profileName must be a character vector or scalar string.');
    end
    if ~(ischar(modelName) || (isstring(modelName) && isscalar(modelName)))
        error('modelName must be a character vector or scalar string.');
    end
    profileName = lower(char(profileName));
    modelName = char(modelName);
    switch profileName
        case 'routing'
            cfg = get_routing_config(modelName);
        case 'ppt'
            cfg = get_ppt_config(modelName);
        otherwise
            error('profileName must be ''routing'' or ''ppt''.');
    end

    previousRng = rng;
    restoreRng = onCleanup(@() rng(previousRng)); %#ok<NASGU>
    rng(2026, 'twister');
    alpha = 0.05;
    satellites = generate_constellation(cfg);
    links = build_isl_links(cfg, satellites);
    graphs = build_isl_graph(cfg, links);
    nodeCount = graphs.node_count;
    edgeCount = graphs.edge_count;

    % Uniform ordered pairs, excluding source = target. Generate once so
    % differences between the three CDFs come only from their routes.
    sourceId = randi(nodeCount, numFlows, 1);
    targetId = randi(nodeCount-1, numFlows, 1);
    targetId = targetId + (targetId >= sourceId);

    methodNames = {'Dijkstra', 'High-latitude', 'Alpha = 0.05'};
    loads = zeros(edgeCount, 3);
    delayMs = zeros(numFlows, 3);
    sameHighAlpha = false(numFlows, 1);
    sameDijkstraHigh = false(numFlows, 1);
    for p = 1:numFlows
        source = sourceId(p);
        target = targetId(p);
        routes = {find_distance_min_path(graphs, source, target), ...
            find_high_latitude_path(cfg, satellites, graphs, source, target), ...
            find_alpha_latitude_path(cfg, satellites, graphs, ...
                source, target, alpha)};
        sameHighAlpha(p) = isequal(routes{2}.node_ids, routes{3}.node_ids);
        sameDijkstraHigh(p) = isequal(routes{1}.node_ids(:), routes{2}.node_ids(:));
        for method = 1:3
            nodes = routes{method}.node_ids(:);
            edgeIds = findedge(graphs.hop, nodes(1:end-1), nodes(2:end));
            if any(edgeIds == 0)
                error('Route %d traversed a missing ISL.', p);
            end
            loads(:,method) = loads(:,method) + ...
                accumarray(edgeIds, 1, [edgeCount,1]);
            delayMs(p,method) = routes{method}.propagation_delay_ms;
        end
    end

    % Every row of links denotes one undirected physical ISL. Reorder
    % endpoint latitudes into graph edge order before weighting the CDFs.
    xyz = reshape(permute(satellites.position_eci_km, [2,1,3]), [], 3);
    latitude = atan2d(xyz(:,3), hypot(xyz(:,1), xyz(:,2)));
    linkLatitude = abs((latitude(links.source_id) + ...
        latitude(links.target_id))/2);
    linkEdgeId = findedge(graphs.hop, links.source_id, links.target_id);
    if any(linkEdgeId == 0) || numel(unique(linkEdgeId)) ~= edgeCount
        error('Link list and graph do not describe the same ISLs.');
    end
    absoluteMeanLatitudeDeg = zeros(edgeCount,1);
    isInter = false(edgeCount,1);
    absoluteMeanLatitudeDeg(linkEdgeId) = linkLatitude;
    isInter(linkEdgeId) = links.type == "inter";

    fig = gobjects(4,1);
    labels = {'All ISLs', 'Inter-plane ISLs', 'Intra-plane ISLs'};
    masks = {true(edgeCount,1), isInter, ~isInter};
    curves = cell(4,3);
    for chart = 1:3
        fig(chart) = figure('Name', ['ISL load CDF - ' labels{chart}], ...
            'Color', 'w');
        ax = axes(fig(chart));
        hold(ax, 'on');
        mask = masks{chart};
        for method = 1:3
            [x, y] = weighted_latitude_cdf( ...
                absoluteMeanLatitudeDeg(mask), loads(mask,method));
            curves{chart,method} = [x,y];
            stairs(ax, x, y, 'LineWidth', 2, ...
                'DisplayName', methodNames{method});
        end
        grid(ax, 'on');
        xlabel(ax, 'Absolute mean endpoint latitude (deg)');
        ylabel(ax, 'CDF of ISL traversals');
        title(ax, sprintf('%s | %s/%s | %d requests', ...
            labels{chart}, profileName, modelName, numFlows));
        xlim(ax, [0, max(1, max(absoluteMeanLatitudeDeg(mask)))]);
        ylim(ax, [0, 1]);
        legend(ax, 'Location', 'southeast');
    end

    fig(4) = figure('Name', 'End-to-end propagation delay CDF', ...
        'Color', 'w');
    ax = axes(fig(4));
    hold(ax, 'on');
    for method = 1:3
        [x, y] = empirical_cdf(delayMs(:,method));
        curves{4,method} = [x,y];
        stairs(ax, x, y, 'LineWidth', 2, ...
            'DisplayName', methodNames{method});
    end
    grid(ax, 'on');
    xlabel(ax, 'End-to-end ISL propagation delay (ms)');
    ylabel(ax, 'CDF of requests');
    title(ax, sprintf('Propagation delay | %s/%s | %d requests', ...
        profileName, modelName, numFlows));
    xlim(ax, [0, max(delayMs(:))*1.02]);
    ylim(ax, [0, 1]);
    legend(ax, 'Location', 'southeast');

    result.cfg = cfg;
    result.num_flows = numFlows;
    result.alpha_per_degree = alpha;
    result.source_id = sourceId;
    result.target_id = targetId;
    result.method_names = methodNames;
    result.edge_load_traversals = loads;
    result.edge_abs_mean_latitude_deg = absoluteMeanLatitudeDeg;
    result.edge_is_inter = isInter;
    result.propagation_delay_ms = delayMs;
    result.high_alpha_same_path_fraction = mean(sameHighAlpha);
    result.dijkstra_high_same_path_fraction = mean(sameDijkstraHigh);
    result.cdf_curves = curves;
    result.figures = fig;

    fprintf('%s/%s, %d requests, alpha=%g per degree.\n', ...
        profileName, modelName, numFlows, alpha);
    fprintf('High-latitude = alpha path: %.1f%%; Dijkstra = high-latitude: %.1f%%.\n', ...
        100*result.high_alpha_same_path_fraction, ...
        100*result.dijkstra_high_same_path_fraction);
    fprintf('Mean propagation delay (ms): Dijkstra %.3f, high-latitude %.3f, alpha %.3f.\n', ...
        mean(delayMs(:,1)), mean(delayMs(:,2)), mean(delayMs(:,3)));
end

function [x, y] = weighted_latitude_cdf(latitudeDeg, traversalCount)
    used = traversalCount > 0;
    if ~any(used)
        x = [0; 1];
        y = [0; 0];
        return
    end
    [sortedLatitude, order] = sort(latitudeDeg(used));
    sortedWeight = traversalCount(used);
    sortedWeight = sortedWeight(order);
    [uniqueLatitude, ~, group] = unique(sortedLatitude);
    weightByLatitude = accumarray(group, sortedWeight);
    x = [0; uniqueLatitude];
    y = [0; cumsum(weightByLatitude)/sum(weightByLatitude)];
end

function [x, y] = empirical_cdf(values)
    [uniqueValues, ~, group] = unique(values(:));
    countByValue = accumarray(group, 1);
    x = [0; uniqueValues];
    y = [0; cumsum(countByValue)/numel(values)];
end
