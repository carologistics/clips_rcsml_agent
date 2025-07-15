import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, SetEnvironmentVariable
from launch.actions import OpaqueFunction
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def launch_with_context(context, *args, **kwargs):
    example_agent_dir = get_package_share_directory('clips_rcsml_agent')
    cx_config_file = os.path.join(example_agent_dir, "config", "config.yaml")

    log_level = LaunchConfiguration('log_level')
    cx_node = Node(
        package='cx_clips_env_manager',
        executable='cx_node',
        output='screen',
        emulate_tty=True,
        parameters=[
            cx_config_file,
        ],
        arguments=['--ros-args', '--log-level', log_level]
    )

    return [cx_node,]

def generate_launch_description():
    declare_log_level_ = DeclareLaunchArgument(
        "log_level",
        default_value='info',
    )
    # The lauchdescription to populate with defined CMDS
    ld = LaunchDescription()
    ld.add_action(declare_log_level_)
    ld.add_action(OpaqueFunction(function=launch_with_context))

    return ld