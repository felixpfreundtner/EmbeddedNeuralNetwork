%% parameters
sweeprec_fs = 15988;
sweepinverse_fs = 16000;
filename = "16k_1_270degree";
filepath_sweeprec = "../../../../recording/recs/" + filename + ".log";
filepath_sweepinverse = "../../../../recording/sweeps/inverse_10Hz_8kHz_linear.wav";
filepath_output = "../../../../recording/irs/" + filename + ".wav";
nOrder = 6;
mic_N = 2;
filter_sweeprec = true;
ir_average = true;
ir_startthreshold = 0.1; % amplitude
ir_startoffset_s = -0.1; % s
sweep_duration_s = 1.0; % s
sweep_pause_s = 1.0; % s
sweep_repeat = 3; % s


%% load inverse sweep
sweepinverse = audioread(filepath_sweepinverse);
sweepinverse = sweepinverse / max(abs(sweepinverse));
sweepinverse_N = length(sweepinverse);

%% load recorded sweep
sweeprec = regexp(fileread(filepath_sweeprec), "\r?\n", "split");
sweeprec = cellfun(@str2num,sweeprec,"UniformOutput",false);
sweeprec = sweeprec(~cellfun("isempty",sweeprec));
sweeprec = cell2mat(sweeprec);
sweeprec = sweeprec / max(abs(sweeprec));
sweeprec_N = length(sweeprec);


%% optimize recorded sweep
if filter_sweeprec
    wn = [10 7900]/(sweeprec_fs/2); % filter band
    [b,a] = butter (nOrder,wn);
    sweeprec = filter(b,a,sweeprec);
end

%% adapt sampling rates
fs = min([sweeprec_fs, sweepinverse_fs]);
[P,Q] = rat(sweeprec_fs/sweepinverse_fs);
sweepinverse = resample(sweepinverse,P,Q);
sweepinverse_N = length(sweepinverse);

%% split channels
sweeprecs_N = sweeprec_N/2;
sweeprecs = zeros(sweeprecs_N,mic_N);
sweeprecs(:,1) = sweeprec(1:sweeprecs_N);
sweeprecs(:,2) = sweeprec(sweeprecs_N+1:2*sweeprecs_N);

%% extract impulse responses
irs_N = sweeprecs_N + sweepinverse_N - 1;
irs = zeros(irs_N, mic_N);
irs(:,1) = fconv(sweeprecs(:,1), sweepinverse);
irs(:,2) = fconv(sweeprecs(:,2), sweepinverse);
irs = irs /max(max(abs(irs)));

%% split up repeated impulse responses into individual impulse responses
irs_Nstart = min([find(irs(:,1) > ir_startthreshold, 1, "first"),find(irs(:,2) > ir_startthreshold, 1, "first")]);
irs = irs(irs_Nstart + round(ir_startoffset_s * fs): irs_Nstart + round(ir_startoffset_s * fs) + (sweep_duration_s + sweep_pause_s)* sweep_repeat * fs - 1, : );
irs = reshape(irs, (sweep_duration_s + sweep_pause_s) *fs, 3, mic_N);
irs_N = irs_N / sweep_repeat;

%% generate average impulse response
if ir_average
    irs = permute(irs, [1,3,2]);
    irs = mean(irs, 3);
end

%% save impulse response
irs = irs /max(max(abs(irs)));
audiowrite(filepath_output, irs, fs);

%% plot impulse response
figure(100)
plot(irs)
