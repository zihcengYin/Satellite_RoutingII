function result = find_hop_min_path(graphs, sourceId, targetId)
%FIND_HOP_MIN_PATH Construct a minimum-hop path on the Walker grid.
%   First takes all intra-plane hops, then all inter-plane hops. Other
%   orders may have the same hop count but a different total distance.
%   indicator_x/y give the signed plane/satellite-index directions;
%   path_vector contains 0 (intra) or 1 (inter) for each hop.

    direction = get_path_direction(graphs, sourceId, targetId);
    pathVector = [zeros(direction.intra_count,1); ...
        ones(direction.inter_count,1)];
    [nodes, distanceKm, delayMs] = follow_path_vector( ...
        graphs, sourceId, targetId, direction, pathVector);
    [~, shortestHopCount] = shortestpath( ...
        graphs.hop, sourceId, targetId);
    if shortestHopCount ~= numel(pathVector)
        error('The configured Walker-grid directions do not minimize hops.');
    end

    result.node_ids = nodes;
    result.path_vector = pathVector;
    result.hop_count = numel(pathVector);
    result.distance_km = distanceKm;
    result.propagation_delay_ms = delayMs;
    result.source_id = sourceId;
    result.target_id = targetId;
    result.indicator_x = direction.indicator_x;
    result.indicator_y = direction.indicator_y;
    result.direction_indicators = direction.direction_indicators;
end
