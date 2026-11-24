function result = find_alpha_latitude_path( ...
        cfg, satellites, graphs, sourceId, targetId, alpha)
%FIND_ALPHA_LATITUDE_PATH Sample a latitude-weighted route.
%   The route uses minimum-hop directions. At each candidate intra-plane
%   position i=0..K_intra, it averages the absolute geocentric latitude
%   of the K_inter satellites reached after successive inter-plane hops.
%   p_i = exp(alpha * mean_abs_latitude_i) / sum_j exp(...).
%   Each inter-plane hop draws a position independently; duplicate draws
%   create consecutive inter-plane hops. 0=intra, 1=inter in path_vector.
%   This randomized route is not a global distance-minimizing guarantee.

    if nargin < 6 || isempty(alpha)
        alpha = 0.05; % per degree; moderate high-latitude preference
    end
    if ~isscalar(alpha) || ~isnumeric(alpha) || ...
            ~isfinite(alpha) || alpha <= 0
        error('alpha must be a positive finite scalar (per degree).');
    end
    direction = get_path_direction(graphs, sourceId, targetId);
    meanAbsLatitudeDeg = mean_candidate_inter_latitudes( ...
        cfg, satellites, graphs, direction);
    candidateCount = direction.intra_count + 1;
    probabilities = zeros(candidateCount,1);
    if direction.inter_count == 0
        probabilities(:) = 1/candidateCount;
        locations = zeros(0,1);
        pathVector = zeros(direction.intra_count,1);
    else
        scores = alpha * meanAbsLatitudeDeg;
        scores = scores - max(scores); % stable softmax
        probabilities = exp(scores) / sum(exp(scores));
        cumulative = cumsum(probabilities);
        cumulative(end) = 1;
        locations = zeros(direction.inter_count,1);
        for j = 1:direction.inter_count
            locations(j) = find(rand < cumulative, 1, 'first') - 1;
        end
        locations = sort(locations);

        pathVector = zeros(direction.hop_count,1);
        cursor = 1;
        previousLocation = 0;
        for j = 1:direction.inter_count
            intraSteps = locations(j) - previousLocation;
            cursor = cursor + intraSteps;
            pathVector(cursor) = 1;
            cursor = cursor + 1;
            previousLocation = locations(j);
        end
    end

    [nodes, distanceKm, delayMs] = follow_path_vector( ...
        graphs, sourceId, targetId, direction, pathVector);
    result.node_ids = nodes;
    result.path_vector = pathVector;
    result.hop_count = numel(pathVector);
    result.distance_km = distanceKm;
    result.propagation_delay_ms = delayMs;
    result.source_id = sourceId;
    result.target_id = targetId;
    result.route_label = 'Latitude-weighted random route';
    result.indicator_x = direction.indicator_x;
    result.indicator_y = direction.indicator_y;
    result.direction_indicators = direction.direction_indicators;
    result.alpha_per_degree = alpha;
    result.mean_abs_latitude_deg = meanAbsLatitudeDeg;
    result.selection_probability = probabilities;
    result.inter_locations_after_intra_hops = locations;
end
