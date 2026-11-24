function location = satellite_lla_from_eci(cfg, satellites)
%SATELLITE_LLA_FROM_ECI Convert one ECI snapshot to geodetic coordinates.
%   LOCATION.by_id is an (M*N)-by-3 array [latitude_deg, longitude_deg,
%   altitude_km] ordered by satellite ID.

    if ~isfield(cfg, 'simulation') || ...
            ~isfield(cfg.simulation, 'epoch_utc') || ...
            ~isfield(satellites, 'position_eci_km') || ...
            ~isfield(satellites, 'time_offset_s')
        error('Missing epoch or satellite ECI coordinates.');
    end
    pos = satellites.position_eci_km;
    M = cfg.model.M;
    N = cfg.model.N;
    if ~isequal(size(pos), [M,N,3]) || ...
            numel(cfg.simulation.epoch_utc) ~= 6
        error('Coordinate dimensions or UTC epoch are invalid.');
    end
    if exist('eci2lla', 'file') ~= 2
        error('eci2lla requires MATLAB Aerospace Toolbox.');
    end

    xyzKm = reshape(permute(pos, [2,1,3]), [], 3);
    epoch = cfg.simulation.epoch_utc;
    utc = datevec(datenum(epoch(1),epoch(2),epoch(3), ...
        epoch(4),epoch(5),epoch(6)+satellites.time_offset_s));
    raw = eci2lla(xyzKm*1000, repmat(utc, M*N, 1), ...
        'IAU-2000/2006');

    location.by_id = [raw(:,1), raw(:,2), raw(:,3)/1000];
    location.epoch_utc = utc;
    location.coordinate_frame = 'WGS84 geodetic';
end
