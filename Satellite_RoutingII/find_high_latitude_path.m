function result = find_high_latitude_path( ...
        cfg, satellites, graphs, sourceId, targetId)
%FIND_HIGH_LATITUDE_PATH Deterministic high-latitude path from paper 5.3.
%   For the minimum-hop direction, choose i* maximizing the mean absolute
%   latitude of the inter-plane candidate satellites. Take i* intra-plane
%   hops, then all inter-plane hops, then remaining intra-plane hops.

    direction = get_path_direction(graphs, sourceId, targetId);
    means = mean_candidate_inter_latitudes( ...
        cfg, satellites, graphs, direction);
    if direction.inter_count == 0
        chosenIntraHops = 0;
    else
        [~, index] = max(means);
        chosenIntraHops = index-1;
    end
    pathVector = [zeros(chosenIntraHops,1); ...
        ones(direction.inter_count,1); ...
        zeros(direction.intra_count-chosenIntraHops,1)];
    [nodes, distanceKm, delayMs] = follow_path_vector( ...
        graphs, sourceId, targetId, direction, pathVector);

    result.node_ids = nodes;
    result.path_vector = pathVector;
    result.hop_count = numel(pathVector);
    result.distance_km = distanceKm;
    result.propagation_delay_ms = delayMs;
    result.source_id = sourceId;
    result.target_id = targetId;
    result.route_label = 'High-latitude constructed route';
    result.indicator_x = direction.indicator_x;
    result.indicator_y = direction.indicator_y;
    result.direction_indicators = direction.direction_indicators;
    result.selected_intra_hops = chosenIntraHops;
    result.selected_mean_abs_latitude_deg = means(chosenIntraHops+1);
    result.candidate_mean_abs_latitude_deg = means;
end
