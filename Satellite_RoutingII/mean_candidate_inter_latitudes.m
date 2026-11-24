function meanAbsLatitudeDeg = mean_candidate_inter_latitudes( ...
        cfg, satellites, graphs, direction)
%MEAN_CANDIDATE_INTER_LATITUDES Paper (14)-(15) for each intra-hop position.
%   Row i+1 corresponds to i completed intra-plane hops. Average the
%   absolute geocentric latitudes of the K_inter satellites reached on
%   successive orbital planes at that fixed satellite index.

    if ~isstruct(satellites) || ...
            ~isfield(satellites, 'position_eci_km') || ...
            ~isequal(size(satellites.position_eci_km), ...
                [graphs.M, graphs.N, 3]) || ...
            cfg.model.M ~= graphs.M || cfg.model.N ~= graphs.N
        error('Satellite positions, graph, and cfg have different sizes.');
    end
    pos = satellites.position_eci_km;
    if any(~isfinite(pos(:)))
        error('Satellite positions must be finite.');
    end
    meanAbsLatitudeDeg = zeros(direction.intra_count+1,1);
    if direction.inter_count == 0
        return
    end

    for i = 0:direction.intra_count
        n = direction.source_mn(2) + i*direction.indicator_y;
        if graphs.intra_plane_wrap
            n = mod(n-1, graphs.N)+1;
        end
        latitudes = zeros(direction.inter_count,1);
        for j = 1:direction.inter_count
            m = direction.source_mn(1) + j*direction.indicator_x;
            if graphs.inter_plane_wrap
                m = mod(m-1, graphs.M)+1;
            end
            xyz = reshape(pos(m,n,:), 1, 3);
            latitudes(j) = abs(atan2d(xyz(3), ...
                hypot(xyz(1), xyz(2))));
        end
        meanAbsLatitudeDeg(i+1) = mean(latitudes);
    end
end
