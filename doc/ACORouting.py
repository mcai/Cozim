#!/usr/bin/python

#
# A Python script to simulate ant colony optimization (ACO) based adaptive routing.
#
# Copyright (C) Min Cai 2015
#

from random import randint

REINFORCEMENT_FACTOR = 0.05


class Pheromone:
    """
    Pheromone.
    """
    def __init__(self, neighbor=-1, value=0.0):
        """
        Create a pheromone.

        :param neighbor: the neighbor router
        :param value: the pheromone value
        :return  the newly created pheromone
        """
        self.neighbor = neighbor
        self.value = value


class AntPacket:
    """
    Ant packet.
    """
    def __init__(self, forward=True, source=-1, destination=-1):
        '''
        Create an ant packet.

        :param forward: a boolean value indicating whether it is a forward ant or a backward ant packet
        :param source: the source router
        :param destination: the destination router
        :return: the newly created ant packet
        '''
        self.size = 8
        self.forward = forward
        self.source = source
        self.destination = destination
        self.memory = []


class RoutingTable:
    """
    Routing table.
    """
    def __init__(self, agent=None):
        """
        Create a routing table.

        :param agent: the ant net agent
        :return: a newly created routing table
        """
        self.agent = agent
        self.pheromones = {}

    def add_entry(self, destination=1, neighbor=-1, pheromone_value=0.0):
        """
        Add a routing table entry.

        :param destination: the destination router
        :param neighbor: the neighbor router
        :param pheromone_value: the pheromone value
        :return: a newly created routing table
        """
        pheromone = Pheromone(neighbor, pheromone_value)

        if destination not in self.pheromones:
            self.pheromones[destination] = []

        self.pheromones[destination].append(pheromone)

    def calculate_random_destination(self, source=-1):
        """
        Calculate a randomly chosen destination router for the specified source router.

        :param source: the source router
        :return: a randomly chosen destination router for the specified source router
        """
        i = randint(0, self.agent.routing.num_routers)

        while i == source:
            i = randint(0, self.agent.routing.num_routers)

        return i

    def calculate_neighbor(self, destination=-1, parent=-1):
        """
        Calculate the neighbor (next hop) router for the specified destination and parent routers.

        :param destination: the destination router
        :param parent: the parent router
        :return: the next hop router for the specified destination and parent routers
        """
        if destination == self.agent.router:
            raise Exception(destination, self.agent.router)

        if destination in self.agent.links:
            return destination

        pheromones_per_destination = self.pheromones[destination]

        max_pheromone_value = 0
        max_pheromone_neighbor = -1

        for pheromone in pheromones_per_destination:
            neighbor = pheromone.neighbor
            pheromone_value = pheromone.value

            if neighbor != parent and pheromone_value > max_pheromone_value:
                max_pheromone_value = pheromone_value
                max_pheromone_neighbor = neighbor

        if max_pheromone_neighbor == -1:
            raise Exception()

        return max_pheromone_neighbor

    def update(self, destination=-1, neighbor=-1):
        """
        Update the routing table by incrementing or evaporating pheromone values.

        :param destination: the destination router
        :param neighbor: the neighbor router
        :return: None
        """
        pheromones_per_destination = self.pheromones[destination]

        for pheromone in pheromones_per_destination:
            if pheromone.neighbor == neighbor:
                pheromone.value += REINFORCEMENT_FACTOR * (1 - pheromone.value)
            else:
                pheromone.value *= (1 - REINFORCEMENT_FACTOR)


class AntNetAgent:
    """
    Ant net agent.
    """
    def __init__(self, routing=None, router=-1, links=None, add_periodic_event_function=None, net_transfer_function=None):
        """
        Create an ant net agent.

        :param routing: the parent ACO routing
        :param router: the parent router
        :param links: the links of the parent router
        :param add_periodic_event_function: the function to add a periodic event
        :param net_transfer_function: the function to perform a network transfer
        :return: a newly created ant net agent
        """
        self.routing = routing
        self.router = router
        self.links = links
        self.net_transfer_function = net_transfer_function

        self.routing_table = RoutingTable(self)
        self.init_routing_table()

        add_periodic_event_function(self.create_and_send_forward_ant_packet, 10000)

    def init_routing_table(self):
        """
        Initialize the routing table.

        :return: None
        """
        for router in range(self.routing.num_routers):
            if self.router != router:
                pheromone_value = 1.0 / len(self.links)

                for neighbor in self.links:
                    self.routing_table.add_entry(router, neighbor, pheromone_value)

    def create_and_send_forward_ant_packet(self):
        """
        Create and send a forward ant packet.

        :return: None
        """
        destination = self.routing_table.calculate_random_destination(self.router)

        packet = AntPacket(True, self.router, destination)
        self.memorize(packet)

        neighbor = self.routing_table.calculate_neighbor(destination, self.router)
        self.send_packet(packet, neighbor)

    def receive_ant_packet(self, packet, parent):
        """
        On receiving an ant packet.

        :param packet: the received packet
        :param parent: the parent router
        :return: None
        """
        if packet.forward:
            self.memorize(packet)
            if self.router != packet.destination:
                self.forward_ant_packet(packet, parent)
            else:
                self.create_and_send_backward_ant_packet(packet)
        else:
            self.update_routing_table(packet)
            if self.router != packet.destination:
                self.backward_ant_packet(packet)

    def forward_ant_packet(self, packet, parent):
        """
        Send the specified forward ant packet to the neighbor router.

        :param packet: the ant packet
        :param parent: the parent router
        :return: None
        """
        neighbor = self.routing_table.calculate_neighbor(packet.destination, parent)
        self.send_packet(packet, neighbor)

    def create_and_send_backward_ant_packet(self, packet):
        """
        Create and send a backward ant packet.

        :param packet: the original ant packet
        :return: None
        """
        temp = packet.source
        packet.source = packet.destination
        packet.destination = temp

        packet.forward = False

        index = len(packet.memory) - 2
        self.send_packet(packet, packet.memory[index])

    def backward_ant_packet(self, packet):
        """
        Send the specified backward ant packet to the neighbor router.

        :param packet: the backward ant packet
        :return: None
        """
        index = -1

        for i in reversed(range(len(packet.memory))):
            router = packet.memory[i]
            if self.router == router:
                index = i
                break

        self.send_packet(packet, packet.memory[index - 1])

    def update_routing_table(self, packet):
        """
        Update the routing table.

        :param packet: the ant packet
        :return: None
        """
        index = -1

        for i, router in packet.memory:
            if self.router == router:
                index = i
                break

        neighbor = packet.memory[index + 1]

        for destination in packet.memory[index + 1, ]:
            self.routing_table.update(destination, neighbor)

    def memorize(self, packet):
        """
        Build the memory of the specified forward ant packet.

        :param packet: the ant packet
        :return: None
        """
        packet.memory.append(self.router)

    def send_packet(self, packet, neighbor):
        """
        Send the ant packet to the neighbor router.

        :param packet: the packet
        :param neighbor: the neighbor router
        :return: None
        """
        self.net_transfer_function(self.router, neighbor, packet, lambda : self.routing.agents[neighbor].receive_ant_packet(packet, self.router))


class ACORouting:
    """
    Ant colony optimization (ACO) based routing policy.
    """
    def __init__(self, add_periodic_event_function=None, get_num_routers_function=None, get_links_function=None, net_transfer_function=None):
        """
        Create an ant colony optimization (ACO) based routing policy.

        :param add_periodic_event_function: the function to add a periodic event
        :param get_num_routers_function: the function to get the number of routers
        :param get_links_function: the function to get the list of links for the specified router
        :param net_transfer_function: the function to perform a network transfer
        :return: a newly created ant colony optimization (ACO) based routing policy
        """
        self.num_routers = get_num_routers_function()

        self.agents = []
        for router in range(self.num_routers):
            self.agents.append(AntNetAgent(self, router, get_links_function(router), add_periodic_event_function, net_transfer_function))

    def calculate_neighbor(self, router, destination):
        """
        Calculate the neighbor router for the specified current router and destination router.
        :param router: the current router
        :param destination: the destination router
        :return: the neighbor router
        """
        return self.agents[router].routing_table.calculate_neighbor(destination, router)


def add_periodic_event(event, period_in_cycles):
    """
    Add a periodic event.

    :param event: the periodic event to be added
    :param period_in_cycles: the period in cycles
    :return: None
    """
    pass # TODO

def get_num_routers():
    """
    Get the number of routers in the network.

    :return: the number of routers in the network
    """
    return 0 # TODO

def get_links(router):
    """
    Get the list of links for the specified router.

    :param router: the router
    :return: the list of links for the specified router
    """
    return [] # TODO

def net_transfer(source, destination, packet, on_completed_callback):
    """
    Perform a network transfer.

    :param source: the source router
    :param destination: the destination router
    :param packet: the packet to be sent
    :param on_completed_callback: the callback action that is performed when the transfer completes
    :return: None
    """
    pass # TODO


if __name__ == '__main__':
    aco_routing = ACORouting(add_periodic_event, get_num_routers, get_links, net_transfer)
    print 'neighbor(0, 1) = %d' % aco_routing.calculate_neighbor(0, 1)
