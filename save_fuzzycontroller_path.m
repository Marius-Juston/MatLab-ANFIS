%save Fuzzy Controller path
xout = evalin('base', 'xout');
x_robot = xout(5,:);
y_robot = xout(6,:);
plot(x_robot, y_robot, 'LineWidth', 3.0); hold on
legend('Waypoints','Waypoints Trajectory','Fuzzy Controller','ANFIS')
xlabel('X(m)')
ylabel('Y(m)')
set(gca,'FontSize',30)