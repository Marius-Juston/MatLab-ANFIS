%after running the simulation, run the line of code below to view a 3d
%render of the sim that uses showmotion

% showmotion(model,tout,[fbanim(xout);squeeze(xout(14:17,:,:))])

clear all; close all; clc; % Clear the workspace and erase the command window.

% ========================== Path Generator ==========================
%Below is the path that we are trying to have the model follow in the
%simulation. It is comprised of a list of target positions of the form 
%[x1 y1;x2 y2; ...;xn yn]
anfis= 0;
% path=[3 0;
%       0 1;
%       5 3;
%       5 -2;
%       5 2];
%path = [5,   0;
%             5,  -5;
%             10, -5;
%             10, 5;
%             15, 5;
%             15, 0;
%             20, 0];
 
path = [5, 0;
        5, 5;
        0, 5;
        0, 0];

% path = [
% 1.71255836508612,0.8884904782755552 ;
% 2.4263622770260893,3.3375278923791427 ;
% 2.6250741142676874,6.086952299974077 ;
% 3.483360445616986,4.284240156791468 ;
% 0.816916926883001,4.221107349307019 ;
% 2.8705955238605747,3.8313811909797373 ;
% 5.181699450884096,4.95102575056366 ;
% 4.482963215550983,4.726571651154595 ;
% 5.605370547237937,3.2209292200900244 ;
% 8.244104318073562,4.978191324013623 ;
% ];

path = [
-0.9734125815538288,-2.8223926830093884 ;
-1.603138654130054,-0.898679512060875 ;
-4.029868002935874,-0.2940277368314863 ;
-4.4592905219861345,-3.064128596075829 ;
-4.129053082678681,-0.2877719433034738 ;
-1.5778695439962576,-1.9640929597233794 ;
0.8673973820007896,-1.963314739452974 ;
1.7124591068767394,0.326104391989567 ;
4.28031135349706,2.404318702072244 ;
3.3015333770424955,3.931203169719696 ;
3.8575130932066917,5.535780119033897 ;
2.0423499268310934,4.570066527393268 ;
1.7136463853320496,2.243148714188952 ;
-0.3999834299022087,3.762964116455918 ;
-0.18473054495042263,6.097561295729548 ;
2.7569027038113783,7.97971846789844 ;
2.033011345768807,10.790177897347888 ;
2.920410734911235,10.28348512701549 ;
2.160676212285932,13.236320329815111 ;
4.929722146313235,10.566266715500664 ;
];


%testCourse2(16, 5, 6, 6, 6, 1.22, 1, 1.2);
%testCourse4(3, 2, 1, 0.8)
%path = [1 0; 1 1];
path=[0 0;path];
%{
path = [      0         0;
   7.7800         0;
   8.6427   -0.3573;
   9.0000   -1.2200;
   9.0000   -4.7800;
   8.6427   -5.6427;
   7.7800   -6.0000;
   1.2200   -8.0000;
   0.3573   -9.3573;
   0.0000   -10.2200;
   0.0000  -10.7800;
   -0.3573  -11.6427;
   -1.2200  -12.0000;
   -3.7800  -12.0000;
   -4.6427  -11.6427;
   -5.0000  -10.7800;
   -8.0000  -5.0000
   -5.0000   -1.2200;
   -4.6427   -0.3573;
   -3.7800         0;
   0 0]
%}


%path = path*[cos(pi/2) -sin(pi/2); sin(pi/2) cos(pi/2)];
%path(:,2) = -1*path(:,2);

pathcount=0;% used by path error calculator
[pathlength,~]=size(path);% used by path error calculator

speed=1.5; %robot linear speed target
width=.323; %width of the robot for angluar velo target to left/right conversion

%--------------------- Reference Frame F0 ----------------------
% Draw the reference frame F_0 axes X_0, Y_0 and Z_0 using the "appearance"
% attribute to provide a visual reference in space
model.appearance.base = ...
  { 'colour', [0.9 0 0], 'line', [0 0 0; 2 0 0], ...
    'colour', [0 0.9 0], 'line', [0 0 0; 0 2 0], ...
    'colour', [0 0.3 0.9], 'line', [0 0 0; 0 0 2]};


% Draw an approximation of the ground through tiles. Also set the ground's
% friction, stifness, damping coefficients
x_aux = -1:1:10;
y_aux = -5:1:5;
A = 0.01; %can be increased to increase the height of the centrally located tiles to help distinguish between them
sigma = 2;
x0 = 6;
y0 = 0;
for x = 2:length(x_aux)
    for y = 2:length(y_aux)
        alt = A*exp(-(((x_aux(x)-x0).^2)/(2*sigma^2)+((y_aux(y)-y0).^2)/(2*sigma^2))); %z/tile height
        
        model.appearance.base = ...
        {model.appearance.base,...
        'tiles', [ x_aux(x-1) x_aux(x);y_aux(y-1) y_aux(y); alt alt], 0.1};
    end
end

K=1e6; %ground stiffness/youngs modulus. used by 3D Ground Contact
D=1000; %ground damping coefficient. used by 3D Ground Contact
Mu=.8; %coefficient of friction. used by 3D Ground Contact



%--------------------- SSMM Model ----------------------
%
% Store all model parameters in a variable called "model".
% model.NB: is the number of bodies in the model.
% Variable model.NB is initialized in zero and incremented whenever a new
% body is added to the model...  This allows to easily expand any model!
model.NB = 0;


%---------------------Floating Base----------------------
%
% To create a floting base, a body (with frame F1) is added and "connected"
% to the reference frame F0 by any 1-DOF joint (e.g. rotary or prismatic),
% which will be later replaced by a full 6-DOF joint using the function 
% floatbase.  The 1-DOF joint is simply a temporary placeholder for the
% 6-DOF joint.
i=1; % This is the first body, and it's index is one.
model.NB=model.NB+1; % model.NB is updated with the new body.

model.jtype{i}  = 'R'; % Any type of joint may be selected

model.parent(i) =  0 ; % The floating base parent is the fixed frame, 
                       % i.e. \lambda(1) = 0

% The initial link-to-link transform from F_0 to F_1 is the identity,
% because at the initial state both frames are align.
model.Xtree{i}  = xlt([0 0 0]);

% The total mass of of the robot is 17 kg, with ~13 kg in the body and 
%~1 kg in each tire.
mass(i)         = 13;

basesize=[.428 .323 .180]; %[x y z] lengths of the base
% For modeling simplicity, the center of mass (COM) of the base is defined
% at the origin of frame F1.
width=basesize(2);
CoM(i,:)        = [0 0 0];

% The rotational inertia for the Jackal is approximated to the rotational
% inertia of a cube of size [.428 .323 .180]  with uniform density and total mass
% equal to mass(i).
Icm(i:i+2,:)    = mass(i)*[basesize(2)^2+basesize(3)^2     0            0;...
                            0           basesize(1)^2+basesize(3)^2       0;...
                            0              0         basesize(1)^2+basesize(2)^2]/12;
                        
                        
% The mass, COM and Icm are employed to build the rigid-body's spatial 
% inertia, which is stored in the model parameter "model.I{1}".
model.I{i}      = mcI(mass(i), CoM(i,:), Icm(i:i+2,:));

% Define the floating base appearance to display/visualize the simulation
% results.
model.appearance.body{1} = {'colour', [250 137 45]/255, 'box',   [-basesize(1)/2 -basesize(2)/2 -basesize(3)/2; basesize(1)/2 basesize(2)/2 basesize(3)/2] }; %If someone is bored they can make a pretty jackal body but im just using a box for now

%--------------------- Wheels ----------------------
% Wheels are the bodies 2, 3, 4 and 5.
for i = 2:5
model.NB=model.NB+1; % Update the body number for each wheel

% Wheels are modeled as rotary joints that rotate about the Y-axis of
% frames F2, F3, F4, and F5 (children of parent frame F1).
model.jtype{i} = 'Ry'; 

% The wheels' parent body is the floating base, i.e. \lambda(i) = 1
model.parent(i) = 1 ;

R = .1; % The wheels radius is .45 m
T = .05; % The thickness of the wheels is .25 m

mass(i)=1; %Each tire weighs 1 kg
Ibig=mass(i)*R^2/2; %moment of intertia about the axis of rotation 
Ismall = mass(i)*(3*R^2 +T^2)/12; %moment of inertia about all axes orthoganal to the axis of rotation

WheelOffset=[basesize(1)*.4 basesize(2)/2+T/2 .06]; % all guesses. positive values for the wheel (center) offset from the center of the base. clearpath does not post this information

% Each wheel has a different location and the 
% link-to-link transform is only a translation of the wheel frame with
% to the body frame without rotation.
if(i==2)model.Xtree{i} = xlt([ WheelOffset(1) -WheelOffset(2)  -WheelOffset(3)]);end %top left
if(i==3)model.Xtree{i} = xlt([-WheelOffset(1) -WheelOffset(2)  -WheelOffset(3)]);end %bottom left
if(i==4)model.Xtree{i} = xlt([ WheelOffset(1)  WheelOffset(2)  -WheelOffset(3)]);end %top right
if(i==5)model.Xtree{i} = xlt([-WheelOffset(1)  WheelOffset(2)  -WheelOffset(3)]);end %bottom right

% Because of the wheel clindrical shape the COM is located at the origin
% of their frame which also coincides with the geometrical centroid of the
% wheel.
CoM(i,:)        = [0 0 0]; 

% The spatial rigid-body inertia is calculated for each wheel using the
% mass, COM and inertia tensor.
model.I{i} = mcI(mass(i),CoM(i,:),diag([Ismall Ibig Ismall])); 

% Define the wheels' visual representation attributes. Also, a red dot is
% added to each wheel as a visual reference, to appreciate the turn of the 
% wheels 
model.appearance.body{i} = { 'colour', [0.1 0.1 0.1],...
                             'facets', 32,...
                             'cyl', [0 -T/2 0; 0 T/2 0], R,...
                             'colour', [0.8 0.1 0.1],...
                             'cyl', [0 -T/2-2e-3 -R*.85; 0 T/2+2e-3 -R*.85],.1*R};
end

%--------------------- Additional Model Parameters ----------------------
% The default gravity is zero, so it must be defined as:
model.gravity = [0 0 -9.8];

% Once each body in the model has been defined, the first body must be 
% turned into a floating base:
model = floatbase(model);
% By doing this, the body 1 has now 6 DOFs and can be tought as if it would
% be formed by the composition of 6 bodies each having a 1-DOF joint.  So
% the first six joint variables belong to body 1, while the wheels which
% to be associated to bodies/frames 2, 3, 4, 5 are now bodies/frames 7, 8,
% 9, 10.  Similarly the model variable model.NB is now valued model.NB+5.

%--------------------- Contact Points (CPs) ----------------------
% The contact points are defined as point that cannot penetrate the ground
% plane defined as the plane z=0 in the frame F0.  Each contact point
% contains information about the body to which it belongs and its location
% in the body's reference frame.

% Floating Base CPs --------------------------------------------
CP_Base =[basesize(1)/2 -basesize(1)/2 basesize(1)/2 -basesize(1)/2 basesize(1)/2 -basesize(1)/2 basesize(1)/2 -basesize(1)/2;... X parameter of each CP
          basesize(2)/2 basesize(2)/2 -basesize(2)/2 -basesize(2)/2 basesize(2)/2 basesize(2)/2 -basesize(2)/2 -basesize(2)/2;... Y parameter of each CP
          basesize(3)/2 basesize(3)/2 basesize(3)/2 basesize(3)/2 -basesize(3)/2 -basesize(3)/2 -basesize(3)/2 -basesize(3)/2];  %Z parameter of each CP
                 
% The body number of each CP
CP_Base_Body_Labels = 6*ones(1,length(CP_Base));

% Total number of CPs for the floating base
CP_Base_Num = length(CP_Base_Body_Labels);


% Wheels' CPs---------------------------------------------------
% Because of the wheels' simmetry, all CPs are located equidistant one
% from another about the perimeter of each wheel.
npt_1 = 32; % 32 CPs per wheel are been modeled

% The position for each CP on a wheel is calculated next.
ang = (0:npt_1-1) * 2*pi / npt_1;
Y = ones(1,npt_1) * T/2;
X = sin(ang) * R;
Z = cos(ang) * R;

CP_Wheel = [ X;...
             Y;...
             Z ];

% A contact point at the center of each wheel is added just to extract the
% position and velocity of each of the wheels.
CP_Wheel = [CP_Wheel [0;0;0]];
          
% Define the corresponding body for the wheels' CPs
CP_Wheel_1_Body_Labels =  7*ones(1,length(CP_Wheel(1,:)));
CP_Wheel_2_Body_Labels =  8*ones(1,length(CP_Wheel(1,:)));
CP_Wheel_3_Body_Labels =  9*ones(1,length(CP_Wheel(1,:)));
CP_Wheel_4_Body_Labels = 10*ones(1,length(CP_Wheel(1,:)));

% The CPs of all four wheels are store in a single variable:
CP_Wheels = [CP_Wheel CP_Wheel CP_Wheel CP_Wheel];

% All the corresponding body label for the wheels' CPs are also stored
% in a single variable:
%Wheels_Parent = [Cuerpo_wheel_1 Cuerpo_wheel_2 Cuerpo_wheel_3 Cuerpo_wheel_4];
CP_Wheels_Body_Labels = [CP_Wheel_1_Body_Labels CP_Wheel_2_Body_Labels...
                         CP_Wheel_3_Body_Labels CP_Wheel_4_Body_Labels];

% Total number of wheel contact points
CP_Wheels_Num = length(CP_Wheel_1_Body_Labels)*4;

%------------------------- Model Format ------------------------
% All the contact points and parents position previously defined
% are put on the Spatial Toolbox format as shown below
model.gc.point = [CP_Base CP_Wheels];
model.gc.body = [CP_Base_Body_Labels CP_Wheels_Body_Labels];

% The simulation in Simulink needs some auxiliar variables that define 
% the starting index of the wheels's CPs within the general CP array 
% (model.gc.point) for each wheel separately.
CP_Wheel_1_Index = length(CP_Base_Body_Labels)+1;
CP_Wheel_2_Index = length(CP_Base_Body_Labels)+length(CP_Wheels_Body_Labels)/4+1;
CP_Wheel_3_Index = length(CP_Base_Body_Labels)+length(CP_Wheels_Body_Labels)*2/4+1;
CP_Wheel_4_Index = length(CP_Base_Body_Labels)+length(CP_Wheels_Body_Labels)*3/4+1;
CP_Wheels_Final_Index = length(CP_Base_Body_Labels)+length(CP_Wheels_Body_Labels)*4/4;

% Auxiliar variables are declared to store the total number of CPs in the
% simulation considering the external forces and without including the
% external forces:
CP_Num = CP_Base_Num + CP_Wheels_Num;
CP_Num_aux = CP_Base_Num + CP_Wheels_Num; 

%-------------------- Initialization --------------------------------
% Finally, the initial condition is declared:
zoff=R+basesize(3)/2-WheelOffset(3)+.05; %initialization zoffset so the model starts 5cm in the air
x_init = [1 0 0 0  0 0 zoff   0 0 0  2 0 0]';
%         |______| |_______| |_____| |____|
%             |        |        |       |->Linear Velocity in F_1
%             |        |        |          Coordinates
%             |        |        |
%             |        |        |->Angular Velocity in F_1 coordinates
%             |        |        
%             |        |->Position relative to F_0
%             |
%             |->Orientation Quaternion
%
q_init = [0 0 0 0]';
qd_init = [0 0 0 0]';