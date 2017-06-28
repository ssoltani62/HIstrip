% Calibration function. Only uses one reflect standard throughout the
% algorithm. Makes no simplifying assumptions.

function[mag_dutS,mag_dut_cal_S,sorted_prop2,sorted_evalues] = calibrate(re_thru,im_thru,...
    re_reflect1,im_reflect1,re_reflect2,im_reflect2,re_line,im_line,...
    re_dut,im_dut,thrulength,linelength,testName)

% Stores relative paths so MATLAB can find the data.
addpath 'Data';
addpath 'Data/Cal-Set-5';
addpath 'Data/ConductorLosses';
addpath 'Data/LinearTapers/Diamond';
addpath 'Data/Exponential Tapers';

% Set the name of the test for graphing function to access
testName = 'Line';
% Here for convenience, want access to all output variables.
re_thru = 'ThruExpTaperBand1GroundV2Real.csv'; 
im_thru = 'ThruExpTaperBand1GroundV2Im.csv';
re_line = 'LineExpTaperNotThruBand1GroundV2Real.csv'; 
im_line = 'LineExpTaperNotThruBand1GroundV2Im.csv';
re_reflect1 = 'ReflectExpTaperBand1GroundV2Real.csv';
im_reflect1 = 'ReflectExpTaperBand1GroundV2Im.csv';
re_reflect2 = re_reflect1;
im_reflect2 = im_reflect1;
re_dut = 'LineExpTaperNotThruBand1GroundV2Real.csv';
im_dut = 'LineExpTaperNotThruBand1GroundV2Im.csv';

thrulength=11.558/1000;
linelength=26.0055/1000;
% Thrulength is 30.598/1000 with connectors; 11.558/1000 without (cs5)
% Linelength is 45.045/1000 with connectors; 26.0055/1000 without

% Reading in all the data from HFSS and converting to generalized S
% parameters (and T parameters for thru, line, DUT.)

% Thru Data
[thruS,thru_freq, tdepth] = readin_HFSS(re_thru,im_thru);
[ts11,ts12,ts21,ts22,~] = generalized_S(thruS,tdepth,4);
tt = genS_to_genT(ts11, ts12, ts21, ts22, tdepth);

% Line Data
[lineS, line_freq,ldepth] = readin_HFSS(re_line,im_line);
[ls11,ls12,ls21,ls22,~] = generalized_S(lineS,ldepth,4);
lt = genS_to_genT(ls11,ls12,ls21,ls22,ldepth);

% Reflect1 Data
[reflect1S,reflect1_freq,r1depth] = readin_HFSS(re_reflect1,...
    im_reflect1);
R1S = generalized_S(reflect1S,r1depth,2);

% DUT Data
[dutS,dut_freq,dutdepth] = readin_HFSS(re_dut,im_dut);
[dutS11,dutS12,dutS21,dutS22,~] = generalized_S(dutS,...
    dutdepth,4);
dutT = genS_to_genT(dutS11,dutS12,dutS21,...
    dutS22,dutdepth);

% Checks to make sure that all of the data has the same number of frequency
% points, and that the thru,line, and DUT matrices are all the same size,
% and the reflect matrices are of identical size. Displays a message if
% something has gone awry.

[depth] = sanitycheck(thru_freq,line_freq,...
    reflect1_freq,reflect2_freq,dut_freq,tdepth,ldepth,r1depth,r2depth,...
    dutdepth,t_sq_size,l_sq_size,r1_sq_size,r2_sq_size,dut_sq_size,...
    R1S,R2S);

% Calculates the propagation constants,eigenvalues, and eigenvectors needed
% for the calibration, and then sorts them into the correct order.
[propagation_constants, eigenvalues, eigenvectors, Q] = ...
    prop_const(lt,linelength, tt, thrulength, depth);
 
[sorted_prop2,sorted_evalues,Ao] = ...
    ordering(eigenvalues, propagation_constants, eigenvectors, depth);

%{
% trying new sorting orders with Ao and prop constants
[sorted_prop2, sorted_evalues, Ao] = ...
    reorder(sorted_evalues, sorted_prop2, Ao, depth, 3); 
%}
    
% Correct the angles in the sorted propagation constants matrix.
sorted_prop2 = angleCorrect(sorted_prop2, depth);
    
% Calculates the partially known error boxes Ao and Bo. 
Bo = Ao_and_Bo(Ao,tt,thrulength,sorted_prop2,depth);

% Calculates G10 and G20 matrices. 
[G10,G20] = G10_and_G20(Ao,Bo,R1S,R2S,depth);

% Calculates the L0 matrix.
[L0,L10,L20,L12] = Lo(G10,G20,depth);

% Calculates the K0 matrix.
[K0] = Ko(G10,G20,L0,depth);

% Calculates the Nxo matrix.
[NX0] = Nxo(Ao,Bo,K0,dutT,depth);

% Generates submatrices of Nxo.
[dut_cal_T11,dut_cal_T12,dut_cal_T21,dut_cal_T22] = ...
    conversion(NX0,depth);

% Returns (mostly) calibrated S-parameters of DUT. Sign ambiguities still
% need to be corrected.
[~,~,~,~,dut_cal_S] = genT_to_genS(dut_cal_T11,dut_cal_T12,dut_cal_T21,...
    dut_cal_T22, depth, 2);

% Need to figure out the phase/sign ambiguities; function goes here.

% Converts the uncalibrated and calibrated S-parameters to dB for graphing.
[mag_dutS,mag_dut_cal_S] = S_to_db(dut_cal_S,dutS11,...
    dutS12,dutS21,dutS22,4,depth);

% Plots the DUT modal S-Parameters.
modal_graphs;
