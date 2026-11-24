function result = find_distance_min_path(graphs, sourceId, targetId)
%FIND_DISTANCE_MIN_PATH Return an ISL path minimizing total physical km.
%   Positive edge lengths allow MATLAB shortestpath to find the global
%   minimum over the satellite graph, without restricting hop count.

    validate_nodes(graphs, sourceId, targetId);
    [nodes, distanceKm] = shortestpath( ...
        graphs.distance_km, sourceId, targetId);
    if isempty(nodes)
        error('No satellite path connects node %d to node %d.', ...
            sourceId, targetId);
    end

    edgeIds = findedge(graphs.hop, nodes(1:end-1), nodes(2:end));
    if any(edgeIds == 0)
        error('Hop and distance graphs have different ISL topologies.');
    end
    result.node_ids = nodes;
    result.hop_count = numel(nodes)-1;
    result.distance_km = distanceKm;
    % All ISLs use the same vacuum light speed, so minimizing distance
    % also minimizes propagation delay (original fun_Graph convention).
    result.propagation_delay_ms = ...
        distanceKm * 1e6 / graphs.speed_m_s;
    result.source_id = sourceId;
    result.target_id = targetId;
    result.route_label = 'Distance-min route';
    % A Dijkstra route may change direction or take extra hops. Describe
    % its actual edges rather than claiming one constant indicator_x/y.
    sourcePlane = floor((nodes(1:end-1)-1)/graphs.N)+1;
    targetPlane = floor((nodes(2:end)-1)/graphs.N)+1;
    result.path_vector = double(sourcePlane(:) ~= targetPlane(:));
end

function validate_nodes(graphs, sourceId, targetId)
    if ~isstruct(graphs) || ~isfield(graphs, 'hop') || ...
            ~isfield(graphs, 'distance_km') || ...
            ~isfield(graphs, 'speed_m_s') || ...
            ~isfield(graphs, 'N') || ...
            ~isa(graphs.hop, 'graph') || ...
            ~isa(graphs.distance_km, 'graph')
        error('graphs must be the output of build_isl_graph.');
    end
    nodeCount = numnodes(graphs.hop);
    if numnodes(graphs.distance_km) ~= nodeCount || ...
            ~isscalar(sourceId) || ~isscalar(targetId) || ...
            ~isnumeric(sourceId) || ~isnumeric(targetId) || ...
            ~isfinite(sourceId) || ~isfinite(targetId) || ...
            sourceId ~= fix(sourceId) || targetId ~= fix(targetId) || ...
            sourceId < 1 || targetId < 1 || ...
            sourceId > nodeCount || targetId > nodeCount
        error('Source and target must be valid satellite IDs.');
    end
end
